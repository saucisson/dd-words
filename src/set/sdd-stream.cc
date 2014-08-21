#include <numeric>
#include <cstdlib>
#include <iostream>
#include <string>
#include <vector>
#include <csignal>

#include "sdd/sdd.hh"
#include "sdd/tools/size.hh"
#include "sdd/tools/nodes.hh"

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
    cerr << "sdd-stream <max-length>" << endl;
    return 1;
  }

  struct sigaction sigIntHandler;
  sigIntHandler.sa_handler = handler;
  sigemptyset (&sigIntHandler.sa_mask);
  sigIntHandler.sa_flags = 0;
  sigaction (SIGINT, &sigIntHandler, NULL);

  size_t max_length = stoi (argv [1]);

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

  // Construct the SDD order: we need one level per letter.
  vector<unsigned int> v (max_length);
  iota (v.begin(), v.end(), 0);
  sdd::order_builder<conf> ob;
  const sdd::order<conf> order (sdd::order_builder<conf> (v.begin(), v.end()));

  size_t inserted = 0;
  size_t dropped  = 0;
  size_t total    = 0;
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
        if (sequence.size () <= max_length)
        {
          collections.emplace_back
            ( order
            , [&](unsigned int pos)
              {
                return pos < line.size()
                     ? values_type {line[pos]}
                     : values_type {'#'};
              });
          inserted += 1;
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
  if (sequence.size () <= max_length)
  {
    collections.emplace_back
      ( order
      , [&](unsigned int pos)
        {
          return pos < line.size()
               ? values_type {line[pos]}
               : values_type {'#'};
        });
    inserted += 1;
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
  cout << "# Nodes: " << sdd::tools::nodes(result).first << endl;
  const auto size = sdd::tools::size(result);
  cout << "Size: " << (size / 1024 / 1024) << " Mbytes" << endl;
  return 0;
}
