#include <numeric>
#include <cstdlib>
#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#include <set>
#include <csignal>
#include <cmath>
#include <ctgmath>

#include "sdd/sdd.hh"
#include "sdd/tools/size.hh"
#include "sdd/tools/nodes.hh"
#include "sdd/tools/arcs.hh"
#include "sdd/tools/sequences.hh"
#include "sdd/tools/dot/sdd.hh"

using namespace std;

static bool finish = false;

void
handler(int s)
{
  finish = true;
}

struct conf
  : public sdd::flat_set_default_configuration
{
  using Identifier = unsigned int;
  using Values     = sdd::values::flat_set<char>;
};
using SDD         = sdd::SDD<conf>;
using values_type = conf::Values;

int
main (int argc, const char** argv)
{
  const auto subsize = 100;
  if (argc == 0)
  {
    cerr << "sdd-stream <min-length> <max-length>" << endl;
    return 1;
  }

  struct sigaction sigIntHandler;
  sigIntHandler.sa_handler = handler;
  sigemptyset (&sigIntHandler.sa_mask);
  sigIntHandler.sa_flags = 0;
  sigaction (SIGINT, &sigIntHandler, NULL);

  size_t min_length = stoi (argv [1]);
  size_t max_length = stoi (argv [2]);

  vector<SDD> collections;
  collections.reserve (subsize);

  conf c;
  c.final_cleanup = false; // don't cleanup memory on manager scope exit.
  c.hom_cache_size = 2; // we don't use homomorphisms.
  c.hom_unique_table_size = 2; // we don't use homomorphisms.
//  c.sdd_intersection_cache_size = 16000000;
//  c.sdd_sum_cache_size = 16000000;
//  c.sdd_difference_cache_size = 16000000;
//  c.sdd_unique_table_size = 10000000;
  auto manager = sdd::init<conf>(c);

  // // Construct the SDD order: we need one level per letter.
  // vector<unsigned int> v (max_length);
  // iota (v.begin(), v.end(), 0);
  sdd::order_builder<conf> ob;
  const sdd::order<conf> order {sdd::order_builder<conf> ()};

  set<char> characters;

  size_t inserted = 0;
  size_t dropped  = 0;
  size_t total    = 0;
  size_t sum_inserted = 0;
  string line;
  line.reserve (80);
  string sequence;
  sequence.reserve (max_length);
  cout << "\033[s" << flush;
  while (getline (cin, line))
  {
    if (line [0] == '>')
    { // starting a new sequence:
      total += 1;
      if (sequence.size () != 0)
      {
        if ((sequence.size() >= min_length) && (sequence.size () <= max_length))
        {
          // cout << endl << sequence << endl;
          SDD word = SDD(0, SDD::eol::flat, sdd::one<conf>());
          for (auto i = 0u; i < sequence.size(); ++i)
          {
            characters.insert (sequence[sequence.size() - i - 1]);
            word = SDD(0, {sequence[sequence.size() - i - 1]}, word);
          }
          collections.emplace_back(word);
          inserted += 1;
          sum_inserted += sequence.size();
        }
        else
          dropped += 1;
        sequence.clear ();
      }
      if (finish)
        break;
    }
    else
      sequence += line;
    if (collections.size () == subsize)
    {
      const auto result = sdd::sum<conf> ( collections.cbegin()
                                         , collections.cend() );
      collections.clear ();
      collections.push_back (result);
    }
    if (total % 200 == 0)
      cout << "\033[u"
           << "inserted: " << inserted
           << " / "
           << "dropped: " << dropped
           << " / "
           << "total: " << total
           << flush;
  }
  if ((sequence.size() >= min_length) && (sequence.size () <= max_length))
  {
    SDD word = SDD(0, SDD::eol::flat, sdd::one<conf>());
    for (auto i = 0u; i < sequence.size(); ++i)
    {
      characters.insert (sequence[sequence.size() - i - 1]);
      word = SDD(0, {sequence[sequence.size() - i - 1]}, word);
    }
    collections.emplace_back(word);
    inserted += 1;
    sum_inserted += sequence.size();
  }
  else
    dropped += 1;
  cout << "\033[u"
       << "inserted: " << inserted
       << " / "
       << "dropped: " << dropped
       << " / "
       << "total: " << total
       << endl;
  const auto result = sdd::sum<conf> ( collections.cbegin()
                                     , collections.cend() );

  cout << "# Words: " << result.size() << endl;
  const auto nodes = sdd::tools::nodes(result).first;
  cout << "# Nodes: " << nodes << endl;
  const auto size = sdd::tools::size(result);
  cout << "Size: " << ceil(static_cast<float>(size) / 1024 / 1024) << " Mbytes" << endl;

  auto frequency = sdd::tools::arcs<conf>(result);
  auto sequences = sdd::tools::sequences<conf>(result);

  size_t max_children = 0;
  for (auto& p : frequency)
  {
    max_children = max_children < p.first
                 ? p.first
                 : max_children;
  }
  size_t expected = 0;
  size_t bitfield_size = ceil(static_cast<float>(characters.size())/8);
  size_t base_size = bitfield_size + 4 + 8 + 1;
  cout << "Bit field size: " << bitfield_size << " bytes" << endl;
  cout << "Base node size: " << base_size << " bytes" << endl;
  const size_t average_length = 100;
  const size_t bitsize = ceil(log2(characters.size()));
  cout << "Bitsize: " << bitsize << endl;
  for (size_t i = 0; i <= max_children; ++i)
  {
    if (frequency[i].first == 0)
      continue;
    cout << left << setw(3) << i
         << " => "
         << left << setw(10) << frequency[i].first
         << right
         << endl;
    size_t subresult = 0;
    size_t subsize   = 0;
    if (i == 1)
    {
      size_t subcount = 0;
      for (const auto& p : sequences)
      {
        size_t size = base_size + 8 + ceil(static_cast<float>(bitsize)* p.first / 8);
        size += size % 8 == 0
              ? 0
              : 8 - (size % 8);

        size *= p.second;
        subresult += size;
        subsize   += p.second;
        subcount  += p.second * p.first;
      }
      subresult += (base_size + 8 + ceil(static_cast<float>(bitsize) / 8)) * (frequency[1].first - subcount);
      size_t average = 150;
      size_t should_size =
        (base_size + 8 + ceil(static_cast<float>(bitsize)*average / 8))
        * frequency[i].first / average;
    }
    else
    {
      size_t size = base_size + i * 8;
      size += size % 8 == 0
            ? 0
            : 8 - (size % 8);
      subresult = size * frequency[i].first;
      subsize   = frequency[i].first;
    }
    expected += subresult;
  }
  cout << "Expected size: " << ceil(static_cast<float>(expected) / 1024 / 1024) << " Mbytes" << endl;
  cout << "Original size: " << ceil(static_cast<float>(sum_inserted) / 1024 / 1024)
       << " Mbytes"
       << endl
       << "Binary size: " << (sum_inserted * bitsize / 8 / 1024 / 1024 + 1)
       << " Mbytes"
       << endl;

  if (nodes <= 5000)
  {
    ofstream of ("machin.dot");
    of << sdd::tools::dot (result, order);
  }

  return 0;
}
