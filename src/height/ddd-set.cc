#include "SDD.h"
#include "IntDataSet.h"
#include <cstdlib>
#include <iostream>
#include <vector>

using namespace std;

int main (int argc, const char** argv)
{
  int WIDTH  = atoi (argv[1]);
  int HEIGHT = atoi (argv[2]);
  SDD result = SDD::one;

  vector<int> values;
  for (int j = 0; j != WIDTH; ++j)
  {
    values.push_back (j);
  }
  const IntDataSet set = IntDataSet (values);


  for (int i = 0; i != HEIGHT; ++i)
  {
    result = SDD (i, set, result);
  }
//  std::cout << "Size: " << result.size()  << std::endl;
//  std::cout << result << std::endl;
}
