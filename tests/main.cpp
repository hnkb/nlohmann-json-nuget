#include <nlohmann/json.hpp>
#include <iostream>

int main()
{
	try
	{
		auto j = nlohmann::json::parse(R"({"success": true})");
		std::cout << "JSON test passed: " << j.dump() << std::endl;
		return 0;
	}
	catch (const std::exception& e)
	{
		std::cerr << "JSON test failed: " << e.what() << std::endl;
		return 1;
	}
}
