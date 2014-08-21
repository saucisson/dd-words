#include "DDD.h"
#include <cstdlib>
#include <iostream>

int main (int argc, const char** argv)
{
  int WIDTH  = atoi (argv[1]);
  int HEIGHT = atoi (argv[2]);
  DDD result = DDD::one;
  for (int i = 0; i != HEIGHT; ++i)
  {
    DDD x = DDD::null;
    for (int j = 0; j != WIDTH; ++j)
    {
      x = x + DDD(i, j, result);
    }
    result = x;
  }
//  std::cout << "Size: " << result.size()  << std::endl;
//  std::cout << result << std::endl;
}
