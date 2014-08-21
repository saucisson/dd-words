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
  if (argc < 3)
  {
    cerr << "Not enough arguments: width height" << endl;
    return 1;
  }

  const size_t width  = stoi (argv[1]);
  const size_t height = stoi (argv[2]);

  cout << "Width: " << width << ", Height: " << height << endl;

  conf c;
//  c.final_cleanup = false;
  c.hom_cache_size = 2;
  c.hom_unique_table_size = 2;
  auto manager = sdd::init<conf>(c);

  /*
  vector<unsigned int> v(height);
  iota(v.begin(), v.end(), 0);
  sdd::order_builder<conf> ob;
  const sdd::order<conf> order(sdd::order_builder<conf>(v.begin(), v.end()));
  */

  values_type values;
  for (char j = 0; j != width; ++j)
    values.insert(j);

  SDD result = sdd::one<conf>();
  for (unsigned int i = 0; i != height; ++i)
  {
    result = SDD (i, values, result);
  }

  //cout << "Size: " << result.size() << " bytes" << endl;

  return 0;
}
