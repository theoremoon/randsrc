import std.stdio;
import bnf.parser;
import bnf.gen;

int main(string[] args)
{
	if (args.length <= 2) {
		writefln("usage: %s <source> <rule>", args[0]);
		return 1;
	}

    auto src = Source.fromFile(args[1]);
	auto syntax = parseSyntax(src);
	
	auto gen = new Generator(syntax);
	writeln(gen.generate(args[2]));

	return 0;
}
