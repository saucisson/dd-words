#include <numeric>
#include <cstdlib>
#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#include <map>
#include <iomanip>
#include <cmath>
#include <algorithm>

#include "sdd/sdd.hh"
#include "sdd/tools/size.hh"
#include "sdd/tools/nodes.hh"
#include "sdd/tools/sdd_statistics.hh"

using namespace std;

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
  const auto subsize = 1000;
  size_t max_size = 1;
  size_t max_name = 1;
  map<string, size_t> counts;
  vector<SDD> collections;
  collections.reserve(subsize);

  conf c;
  c.final_cleanup = false; // don't cleanup memory on manager scope exit.
  c.hom_cache_size = 2; // we don't use homomorphisms.
  c.hom_unique_table_size = 2; // we don't use homomorphisms.
//  c.sdd_intersection_cache_size = 16000000;
  c.sdd_sum_cache_size = 16000000;
//  c.sdd_difference_cache_size = 16000000;
//  c.sdd_unique_table_size = 10000000;
  auto manager = sdd::init<conf>(c);

  if (argc == 0)
  {
    cerr << "No arguments" << endl;
    return 1;
  }

  string line;
  line.reserve(32000);

  const size_t max_length = [&]
  {
    size_t length = 0;
    for (size_t param = 1; param < argc; ++param)
    {
      const string filename = argv[param];
      max_name = max (max_name, filename.length());
      ifstream dict(filename);
      if (dict.is_open())
      {
        size_t count = 0;
        while (std::getline(dict, line))
        {
          count++;
          length = length > line.size() ? length : line.size();
        }
        counts [filename] = count;
        max_size = max (max_size, count > 0 ? (size_t) log10 ((double) count) + 1 : 1);
      }
      else
      {
        cerr << "Warning, can't open " << filename << endl;
      }
    }
    return length;
  }();

  cout << "Max word length is " << max_length << endl;

  const sdd::order<conf> order{sdd::order_builder<conf>()};

  for (size_t param = 1; param < argc; ++param)
  {
    string filename = argv[param];
    ifstream dict (filename);
    if (dict.is_open())
    {
      size_t count = 0;
      size_t max = counts [filename];
      cout << setw(max_name + 5) << left << filename
           << right << "\033[s"
           << "\033[u"
           << setw(max_size) << count << " / " << setw(max_size) << max
           << flush;
      while (getline(dict, line))
      {
        count++;
        SDD word = SDD(0, SDD::eol::flat, sdd::one<conf>());
        for (auto i = 0u; i < line.size(); ++i)
        {
          word = SDD(0, {line[line.size() - i - 1]}, word);
        }

        collections.emplace_back(word);
        if (collections.size() == subsize)
        {
          const auto result = sdd::sum<conf>(collections.cbegin(), collections.cend());
          collections.clear();
          collections.push_back(result);
        }
        if (count % 1000 == 0)
        {
          cout << "\033[u"
               << setw(max_size) << count << " / " << setw(max_size) << max
               << flush;
        }
      }
      cout << "\033[u"
           << setw(max_size) << count << " / " << setw(max_size) << max
           << flush;
    }
    else
    {
      cerr << "Warning, can't open " << filename << endl;
    }
    dict.close();
    cout << endl;
  }
  const auto result = sdd::sum<conf>(collections.cbegin(), collections.cend());
  cout << "# Words: " << result.size() << endl;
  const auto nodes = sdd::tools::nodes(result).first;
  cout << "# Nodes: " << nodes << endl;
  const auto size = sdd::tools::size(result);
  cout << "Size: " << (size / 1024 / 1024) << " Mbytes" << endl;
  cout << "Average node size: " << (size / nodes) << " bytes" << endl;

  auto frequency = sdd::tools::sdd_statistics<conf>(result).frequency;
  size_t max_children = 0;
  for (auto& p : frequency)
    max_children = max_children < p.first
                 ? p.first
                 : max_children;
  for (size_t i = 0; i < max_children; ++i)
    if (frequency[i].first != 0)
      cout << setw(3) << i << " => " << frequency[i].first << endl;

  size_t expected = 0;
  max_children += 1;
  size_t bitfield_size =  max_children / 8
                       + (max_children % 8 == 0 ? 0 : 1);
  size_t base_size = bitfield_size + 4 + 8;
  cout << "Bit field size: " << bitfield_size << " bytes" << endl;
  cout << "Base node size: " << base_size << " bytes" << endl;
  const auto average_length = 5;
  for (size_t i = 0; i < max_children; ++i)
  {
    if (i == 1)
    {
      size_t size = base_size + i * 8 + average_length + 8;
      size += size % 8 == 0
            ? 0
            : 8 - (size % 8);
      expected += size * (frequency[i].first / average_length);
    }
    else
    {
      size_t size = base_size + i * 8;
      size += size % 8 == 0
            ? 0
            : 8 - (size % 8);
      expected += size * frequency[i].first;
    }
  }
  cout << "Expected size: " << (expected / 1024 / 1024) << " Mbytes" << endl;

  return 0;
}
