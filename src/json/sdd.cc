#include <iostream>
#include <fstream>
#include <string>

#include "sdd/sdd.hh"
//#include "sdd/tools/dot/sdd.hh"
#include "sdd/tools/order.hh"
#include "sdd/tools/size.hh"

/*------------------------------------------------------------------------------------------------*/

struct conf
  : public sdd::flat_set_default_configuration
{
  using Identifier = std::string;
  using Values     = sdd::values::flat_set<int>;
};
using SDD         = sdd::SDD<conf>;
using values_type = conf::Values;

/*------------------------------------------------------------------------------------------------*/

SDD
load_object(const rapidjson::Value&, sdd::order<conf>);

SDD
load_array(const rapidjson::Value& arr, sdd::order<conf> o);

SDD
load_string(const rapidjson::Value& str)
{
  constexpr auto max = 13;
  assert(str.IsString());
  const auto ch = str.GetString();
  const auto sz = str.GetStringLength();
  SDD res = sdd::one<conf>();
  for (unsigned int i = 0; i < max - sz; ++i)
  {
    res = SDD(i, {std::numeric_limits<int>::max()}, res);
  }
  std::size_t index = sz;
  for (unsigned int i = max - sz; i < max; ++i)
  {
    res = SDD(i, {ch[index - 1]}, res);
    --index;
  }
  return res;
}

std::pair<SDD, unsigned int>
load_array_impl(const rapidjson::Value& arr, sdd::order<conf> o, rapidjson::SizeType index)
{
  assert(arr.IsArray());
  if (index == arr.Size())
  {
    return {sdd::one<conf>(), 0};
  }
  else
  {
    const auto res = load_array_impl(arr, o.next(), index + 1);

    const auto& v = arr[index];

    if (v.IsInt())
    {
      return {SDD(res.second, {v.GetInt()}, res.first), res.second + 1};
    }
    else if (v.IsString())
    {
      return {SDD(res.second, load_string(v), res.first), res.second + 1};
    }
    else if (v.IsObject())
    {
      return {SDD(res.second, load_object(v, o.nested()), res.first), res.second + 1};
    }
    else if (v.IsArray())
    {
      return {SDD(res.second, load_array(v, o.nested()), res.first), res.second + 1};
    }
    else if (v.IsNull_())
    {
      if (o.nested().empty())
      {
        return {SDD(res.second, {std::numeric_limits<int>::max()}, res.first), res.second + 1};
      }
      else
      {
        const auto init = [](const std::string&) -> values_type
        {
          return {std::numeric_limits<int>::max()};
        };
        return {SDD(res.second, SDD(o.nested(), init), res.first), res.second + 1};
      }
    }
    else
    {
      throw "not an Int or Array or or Null or Object in Array";
    }
  }
}

SDD
load_array(const rapidjson::Value& arr, sdd::order<conf> o)
{
  return load_array_impl(arr, o, 0u).first;
}

std::pair<SDD, unsigned int>
load_object_impl( const rapidjson::Value& obj, sdd::order<conf> o
                , rapidjson::Value::ConstMemberIterator it)
{
  assert(obj.IsObject());
  if (it == obj.MemberEnd())
  {
    return {sdd::one<conf>(), 0};
  }
  else
  {
    const auto res = load_object_impl(obj, o.next(), it + 1);

    if (it->value.IsInt())
    {
      return {SDD(res.second, {it->value.GetInt()}, res.first), res.second + 1};
    }
    else if (it->value.IsString())
    {
      return {SDD(res.second, load_string(it->value.GetString()), res.first), res.second + 1};
    }
    else if (it->value.IsObject())
    {
      return {SDD(res.second, load_object(it->value, o.nested()), res.first), res.second + 1};
    }
    else if (it->value.IsArray())
    {
      return {SDD(res.second, load_array(it->value, o.nested()), res.first), res.second + 1};
    }
    else
    {
      throw "not an Int or Array or Object in Object";
    }
  }
}

SDD
load_object(const rapidjson::Value& obj, sdd::order<conf> o)
{
  return load_object_impl(obj, o, obj.MemberBegin()).first;
}

SDD
load_doc(const rapidjson::Value& v, sdd::order<conf> o)
{
  using namespace rapidjson;
  if (v.IsObject())
  {
    return load_object(v, o);
  }
  else
  {
    throw "Document is not an Object";
  }
}

/*------------------------------------------------------------------------------------------------*/

int
main(int argc, char** argv)
{
  conf c;
  c.final_cleanup = false;
  c.hom_unique_table_size = 0;
  c.hom_cache_size = 0;
  auto manager = sdd::init<conf>();

  if (argc < 3)
  {
    std::cerr << "Wrong number of arguments." << std::endl;
    return 1;
  }

  // Open order file.
  std::fstream file(argv[1]);
  if (not file.is_open())
  {
    std::cerr << "Can't open " << argv[1] << std::endl;
    return 2;
  }

  // Load JSON documents file.
  std::fstream jsons(argv[2]);
  if (not jsons.is_open())
  {
    std::cerr << "Can't open " << argv[2] << std::endl;
    return 3;
  }

  // Load order.
  const sdd::order<conf> o = sdd::tools::load_order<conf>(file);
//  std::cout << o << std::endl;

  // Load JSON file in memory.
  std::string buffer;
  buffer.reserve(16384);
  {
    std::string line;
    while(std::getline(jsons, line))
    {
      buffer += line;
    }
  }

  // Parse JSON documents.
  rapidjson::Document doc;
  doc.Parse<0>(&buffer[0]);
  if (not doc.IsArray())
  {
    std::cerr << "Top element should be a list" << std::endl;
  }

  std::vector<SDD> res;
  std::vector<SDD> sub;
  res.reserve(1000);
  sub.reserve(1000);

  for (unsigned int i = 0; i < doc.Size(); ++i)
  {
    sub.emplace_back(load_doc(doc[i], o));
    if (i % 1000 == 0)
    {
      res.emplace_back(sdd::sum<conf>(sub.cbegin(), sub.cend()));
      sub.clear();
    }
  }
  res.emplace_back(sdd::sum<conf>(sub.cbegin(), sub.cend()));
  const auto all = sdd::sum<conf>(res.cbegin(), res.cend());
  std::cout << all.size() << std::endl;
  std::cout << sdd::tools::size(all) << " bytes" << std::endl;
//  std::cout << all << std::endl;

  return 0;
}