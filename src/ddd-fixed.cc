#include <cstdlib>
#include <iostream>
#include <fstream>
#include <string>

#include <DDD.h>
#include <SDD.h>
#include <MemoryManager.h>

using namespace std;

int main (int argc, const char** argv)
{
  vector<DDD> collections;

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
        for (size_t i = max_size; i != line.length(); --i)
        {
          word = DDD(0, '\0', word);
        }
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
  cout << endl;
  DDD collection = DDD::null;
  for (DDD& d : collections)
    collection = collection + d;
  cout << endl;
  cout << "# Words: " << collection.set_size() << endl;
  cout << "# Nodes: " << collection.size()     << endl;
}
