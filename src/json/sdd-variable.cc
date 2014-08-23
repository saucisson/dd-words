#include <iostream>
#include <fstream>
#include <string>

#include "sdd/sdd.hh"
#include "sdd/tools/dot/sdd.hh"
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
load_object(const rapidjson::Value&);

SDD
load_array(const rapidjson::Value&);

SDD
load_string(const rapidjson::Value& str)
{
  const auto ch = str.GetString();
  const auto sz = str.GetStringLength();

  SDD res = SDD(0, SDD::eol::flat, sdd::one<conf>());

  for (unsigned int i = 0; i < sz; ++i)
  {
    res = SDD(0, {ch[sz - i - 1]}, res);
  }
  return res;
}

SDD
load_array_impl(const rapidjson::Value& arr, rapidjson::SizeType index)
{
  assert(arr.IsArray());
  if (index == arr.Size())
  {
    return SDD(0, SDD::eol::hierarchical, sdd::one<conf>());
  }
  else
  {
    const auto res = load_array_impl(arr, index + 1);

    const auto& v = arr[index];

    if (v.IsInt())
    {
      return SDD(0, {v.GetInt()}, res);
    }
    else if (v.IsString())
    {
      return SDD(0, load_string(v), res);
    }
    else if (v.IsObject())
    {
      return SDD(0, load_object(v), res);
    }
    else if (v.IsArray())
    {
      return SDD(0, load_array(v), res);
    }
    else if (v.IsNull_())
    {
      return SDD(0, SDD::eol::hierarchical, sdd::one<conf>());
    }
    else
    {
      throw "not an Int or Array or or Null or Object in Array";
    }
  }
}

SDD
load_array(const rapidjson::Value& arr)
{
  return load_array_impl(arr, 0u);
}

std::pair<SDD, unsigned int>
load_object_impl(const rapidjson::Value& obj, rapidjson::Value::ConstMemberIterator it)
{
  assert(obj.IsObject());
  if (it == obj.MemberEnd())
  {
    return {sdd::one<conf>(), 0};
  }
  else
  {
    const auto res = load_object_impl(obj, it + 1);

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
      return {SDD(res.second, load_object(it->value), res.first), res.second + 1};
    }
    else if (it->value.IsArray())
    {
      return {SDD(res.second, load_array(it->value), res.first), res.second + 1};
    }
    else
    {
      throw "not an Int or Array or Object in Object";
    }
  }
}

SDD
load_object(const rapidjson::Value& obj)
{
  return load_object_impl(obj, obj.MemberBegin()).first;
}

SDD
load_doc(const rapidjson::Value& v)
{
  using namespace rapidjson;
  if (v.IsObject())
  {
    return load_object(v);
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

  for (auto i = 0u; i < doc.Size(); ++i)
  {
    sub.emplace_back(load_doc(doc[i]));
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

  std::ofstream f("/Users/hal/Desktop/foo.dot");
  if (f.is_open())
  {
    f << sdd::tools::dot(all, o);
  }

  return 0;
}
