#include <numeric>
#include <cstdlib>
#include <iostream>
#include <fstream>
#include <string>
#include <vector>

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

  const size_t max_size = [&]
  {
    size_t max = 0;
    for (size_t param = 1; param < argc; ++param)
    {
      const string filename = argv[param];
      ifstream dict(filename);
      if (dict.is_open())
      {
        while (std::getline(dict, line))
        {
          max = max > line.size() ? max : line.size();
        }
      }
      else
      {
        cerr << "Warning, can't open " << filename << endl;
      }
    }
    return max;
  }();

  cout << "Max word length is " << max_size << endl;

  // Construct the SDD order: we need one level per letter.
  vector<unsigned int> v(max_size);
  iota(v.begin(), v.end(), 0);
  sdd::order_builder<conf> ob;
  const sdd::order<conf> order(sdd::order_builder<conf>(v.begin(), v.end()));

  for (size_t param = 1; param < argc; ++param)
  {
    cout << argv[param] << endl;
    string filename = argv[param];
    ifstream dict (filename);
    if (dict.is_open())
    {
      size_t count = 0;

      while (getline(dict, line))
      {
        count++;
        subcollection.emplace_back(SDD(order, [&](unsigned int pos) 
                                              {
                                                return pos < line.size()
                                                     ? values_type {line[pos]}
                                                     : values_type {'#'};
                                              }));
        if (count == subsize)
        {
          collections.emplace_back(sdd::sum<conf>(subcollection.cbegin(), subcollection.cend()));
          subcollection.clear();
          count = 0;
          cout << "." << flush;
        }
      }
      collections.emplace_back(sdd::sum<conf>(subcollection.cbegin(), subcollection.cend()));
    }
    else
    {
      cerr << "Warning, can't open " << filename << endl;
    }
    dict.close();
    cout << endl;
  }
  cout << endl;
  const auto collection = sdd::sum<conf>(collections.cbegin(), collections.cend());
  cout << endl;
  cout << "# Words: " << collection.size() << endl;
  cout << "size: " << sdd::tools::size(collection) << " bytes" << endl;

  return 0;
}
