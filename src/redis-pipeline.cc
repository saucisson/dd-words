#include "hiredis/hiredis.h"
#include <cstdlib>
#include <iostream>
#include <fstream>
#include <string>

using namespace std;

int
main (int argc, const char** argv)
{
  auto context = redisConnect("127.0.0.1", 6379);
//  auto context = redisConnectUnix("/tmp/redis.sock");
  if (context != NULL && context->err) {
    cerr << "Error: " << context->errstr << endl;
    return 1;
  }
  redisCommand (context, "FLUSHDB");
  string line;
  for (size_t param = 1; param < argc; ++param)
  {
    cout << argv [param] << endl;
    string filename = argv[param];
    ifstream dict (filename);
    if (dict.is_open())
    {
      size_t count = 0;
      while (getline(dict, line))
      {
        redisAppendCommand (context, "SET %s true", line.c_str());
        count++;
        if (count == 10000)
        {
          for (size_t j = 0; j < count; ++j)
            redisGetReply (context, NULL);
          count = 0;
          cout << "." << flush;
        }
      }
    }
    dict.close();
    cout << endl;
  }
  cout << endl;
  auto reply = (redisReply*) redisCommand (context, "DBSIZE");
  cout << "# Words: " << reply->integer << endl;
}

