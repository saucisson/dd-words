#include <cstdlib>
#include <iostream>
#include <fstream>
#include <string>
#include <vector>

#include "sdd/sdd.hh"

using namespace std;

struct conf
  : public sdd::flat_set_default_configuration
{
  using Identifier = unsigned int;
  using Values     = sdd::values::flat_set<char>;
};
using SDD         = sdd::SDD<conf>;
using values_type = conf::Values;

int main (int argc, const char** argv)
{
  auto manager = sdd::init<conf>();
  vector<SDD> collections;

  size_t max_size = stoi (argv [1]);
  // Construct the SDD order: we need one level per letter.
  vector<unsigned int> v(max_size);
  iota(v.begin(), v.end(), 0);
  sdd::order_builder<conf> ob;
  const sdd::order<conf> order(sdd::order_builder<conf>(v.begin(), v.end()));

  string line;
  for (size_t param = 2; param < argc; ++param)
  {
    cout << argv [param] << endl;
    string filename = argv[param];
    ifstream dict (filename);
    if (dict.is_open())
    {
      size_t count = 0;
      SDD subcollection = sdd::zero<conf>();
      while (getline(dict, line))
      {
        count++;
        subcollection += SDD(order, [&](unsigned int pos) {
          return pos < line.size()
               ? values_type {line[pos]}
               : values_type {'#'};
        });
        if (count == 10000)
        {
          collections.push_back (subcollection);
          subcollection = sdd::zero<conf>();
          count = 0;
          cout << "." << flush;
        }
      }
      collections.push_back (subcollection);
    }
    dict.close();
    cout << endl;
  }
  cout << endl;
  SDD collection = sdd::zero<conf>();
  for (const SDD& d : collections)
    collection += d;
  cout << endl;
  cout << "# Words: " << collection.size() << endl;
}
