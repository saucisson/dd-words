#include <cstdlib>
#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#include <map>
#include <iomanip>
#include <cmath>
#include <algorithm>

#include <DDD.h>
#include <SDD.h>
#include <MemoryManager.h>

using namespace std;

int main (int argc, const char** argv)
{
  const auto subsize = 1000;
  size_t max_size = 1;
  size_t max_name = 1;
  map<string, size_t> counts;
  vector<DDD> collections;

  if (argc == 0)
  {
    cerr << "No arguments" << endl;
    return 1;
  }

  string line;
  line.reserve(256);

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
      }
      counts [filename] = count;
      max_size = max (max_size, count > 0 ? (size_t) log10 ((double) count) + 1 : 1);
    }
    else
    {
      cerr << "Warning, can't open " << filename << endl;
    }
  }

  for (size_t param = 1; param < argc; ++param)
  {
    string filename = argv[param];
    ifstream dict (filename);
    if (dict.is_open())
    {
      size_t cycles = 0;
      size_t count = 0;
      size_t max = counts [filename];
      cout << setw(max_name + 5) << left << filename
           << right << "\033[s"
           << "\033[u"
           << setw(max_size) << count << " / " << setw(max_size) << max
           << flush;
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
        if (count % subsize == 0)
        {
          collections.push_back (subcollection);
          subcollection = DDD::null;
          cycles++;
          cout << "\033[u"
               << setw(max_size) << count << " / " << setw(max_size) << max
               << flush;
        }
      }
      collections.push_back (subcollection);
      cout << "\033[u"
           << setw(max_size) << count << " / " << setw(max_size) << max
           << flush;
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
