#include <hiredis/hiredis.h>
#include <cstdlib>
#include <iostream>
#include <fstream>
#include <string>
#include <map>
#include <iomanip>
#include <cmath>
#include <algorithm>

using namespace std;

int
main (int argc, const char** argv)
{
  const auto subsize = 10000;
  size_t max_size = 1;
  size_t max_name = 1;
  map<string, size_t> counts;

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

  auto context = redisConnect("127.0.0.1", 6379);
//  auto context = redisConnectUnix("/tmp/redis.sock");
  if (context != NULL && context->err) {
    cerr << "Error: " << context->errstr << endl;
    return 1;
  }
  redisCommand (context, "FLUSHDB");
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
        redisCommand (context, "SET %s true", line.c_str());
        count++;
        if (count % subsize == 0)
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
    dict.close();
    cout << endl;
  }
  auto reply = (redisReply*) redisCommand (context, "DBSIZE");
  cout << "# Words: " << reply->integer << endl;
}

