import std.stdio;
import bnf.parser;

int main(string[] args)
{
	if (args.length == 1) {
		writefln("usage: %s <source>", args[0]);
		return 1;
	}

    auto src = Source.fromFile(args[1]);
	auto syntax = parseSyntax(src);
	
	foreach (rule; syntax) {
		writefln("%s ::= %s", rule.name.toString(), rule.expr.toString());
	}

	return 0;
}
