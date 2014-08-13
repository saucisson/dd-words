#include <cstdlib>
#include <iostream>
#include <fstream>
#include <string>
#include <vector>

#include <DDD.h>
#include <SDD.h>
#include <MemoryManager.h>

using namespace std;

int main (int argc, const char** argv)
{
  vector<DDD> collections;

  string line;
  for (size_t param = 1; param < argc; ++param)
  {
    cout << argv [param] << endl;
    string filename = argv[param];
    ifstream dict (filename);
    if (dict.is_open())
    {
      size_t cycles = 0;
      size_t count = 0;
      DDD subcollection = DDD::null;
      while (getline(dict, line))
      {
        count++;
        DDD word = DDD(0, '\0', DDD::one);
        for(auto i = line.rbegin(); i != line.rend(); ++i)
        {
          word = DDD(0, *i, word);
        }
        subcollection = subcollection + word;
        if (cycles == 100)
        {
          MemoryManager::garbage();
          cycles = 0;
        }
        if (count == 10000)
        {
          collections.push_back (subcollection);
          subcollection = DDD::null;
          count = 0;
          cycles++;
          cout << "." << flush;
        }
      }
      collections.push_back (subcollection);
    }
    dict.close();
    MemoryManager::garbage();
    cout << endl;
  }
  DDD collection = DDD::null;
  for (DDD& d : collections)
    collection = collection + d;
  cout << "# Words: " << collection.set_size() << endl;
  cout << "# Nodes: " << collection.size()     << endl;
}
