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
  const auto subsize = 10000;
  size_t max_size = 1;
  size_t max_name = 1;
  map<string, size_t> counts;
  vector<SDD> collections;
  vector<SDD> subcollection;
  subcollection.reserve(subsize);

  conf c;
  c.final_cleanup = false; // don't cleanup memory on manager scope exit.
  c.hom_cache_size = 2; // we don't use homomorphisms.
  c.hom_unique_table_size = 2; // we don't use homomorphisms.
  auto manager = sdd::init<conf>(c);

  if (argc == 0)
  {
    cerr << "No arguments" << endl;
    return 1;
  }

  string line;
  line.reserve(256);

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

  // Construct the SDD order: we need one level per letter.
  vector<unsigned int> v(max_length);
  iota(v.begin(), v.end(), 0);
  sdd::order_builder<conf> ob;
  const sdd::order<conf> order(sdd::order_builder<conf>(v.begin(), v.end()));

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
        subcollection.emplace_back(order, [&](unsigned int pos)
                                             {
                                               return pos < line.size()
                                                    ? values_type {line[pos]}
                                                    : values_type {'#'};
                                             });
        if (count % subsize == 0)
        {
          collections.emplace_back(sdd::sum<conf>(subcollection.cbegin(), subcollection.cend()));
          subcollection.clear();
          cout << "\033[u"
               << setw(max_size) << count << " / " << setw(max_size) << max
               << flush;
        }
      }
      collections.emplace_back(sdd::sum<conf>(subcollection.cbegin(), subcollection.cend()));
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
  const auto collection = sdd::sum<conf>(collections.cbegin(), collections.cend());
  cout << "# Words: " << collection.size() << endl;
  cout << "Size: " << sdd::tools::size(collection) << " bytes" << endl;

  return 0;
}
