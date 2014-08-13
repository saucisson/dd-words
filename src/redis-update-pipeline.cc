#include "hiredis/hiredis.h"
#include <cstdlib>
#include <iostream>
#include <fstream>
#include <string>
#include <cstring>

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
  redisReply* reply;
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
          {
            redisGetReply (context, (void**) &reply);
          }
          count = 0;
          cout << "." << flush;
        }
      }
      for (size_t j = 0; j < count; ++j)
      {
        redisGetReply (context, (void**) &reply);
      }
    }
    dict.close();
    cout << endl;
  }
  reply = (redisReply*) redisCommand (context, "DBSIZE");
  cout << "# Words: " << reply->integer << endl;
  reply = (redisReply*) redisCommand (context, "KEYS *e");
  char buffer [256];
  size_t count = 0;
  cout << "Updating " << reply->elements << " elements..." << endl;
  for (size_t i = 0; i < reply->elements; ++i)
  {
    auto key = reply->element [i]->str;
    size_t length = strlen (key);
    if (key [length-1] == 'e')
    {
      count++;
      strncpy (buffer, key, length);
      buffer [length-1] = '\0';
      redisAppendCommand (context, "RENAME %s %s", key, buffer);
    }
  }
  for (size_t i = 0; i < count; ++i)
  {
    redisGetReply (context, (void**) &reply);
  }
  reply = (redisReply*) redisCommand (context, "DBSIZE");
  cout << "# Words: " << reply->integer << endl;
}

