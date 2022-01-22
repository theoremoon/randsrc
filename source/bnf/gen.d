module bnf.gen;
import std.format;
import std.random;
import std.typecons : Rebindable;
import std.range : iota;
import std.algorithm;
import std.array;

import bnf.ast;

const MAX_REPETITIONS = 10;

class Generator {
    private:
        Rebindable!(const AST)[string] rules;
        Random rnd;
        
    public:
        this(in Rule[] syntax) {
            this.rules["EOL"] = new Literal("\n");
            this.rules["EOF"] = new EOF();
            foreach (rule; syntax) {
                const ruleName = cast(RuleName)rule.name;
                this.rules[ruleName.getName] = rule.expr;
            }
            this.rnd = rndGen();
        }
        void setRnd(Random rnd) {
            this.rnd = rnd;
        }

        string generate(string name) {
            if (name !in this.rules) {
                throw new Exception("unknown rule %s".format(name));
            }
            const rule = this.rules[name];
            return this.generate(rule);
        }

        string generate(in AST rule) {
            final switch (rule.type) {
                case ASTType.OPTIONAL:
                    if (uniform(0, 2, this.rnd) == 0) {
                        return "";
                    }
                    const optional = cast(Optional)rule;
                    const r = optional.getRule;
                    return this.generate(r);

                case ASTType.REPEAT:
                    const rep = cast(Repeat)rule;
                    const r = rep.getRule;
                    return iota(0, uniform(0, MAX_REPETITIONS, this.rnd)).map!(x => this.generate(r)).join("");

                case ASTType.CHOICE:
                    const choice = cast(Choice)rule;
                    const r = choice.getChoices().choice(this.rnd);
                    return this.generate(r);

                case ASTType.LIST:
                    char[] s = [];
                    const list = cast(List)rule;
                    foreach (r; list.getRules) {
                        s ~= this.generate(r);
                    }
                    return s.idup;

                case ASTType.RULENAME:
                    const r = cast(RuleName)rule;
                    if (r.getName !in this.rules) {
                        throw new Exception("unknown rule %s".format(r.getName));
                    }
                    return this.generate(this.rules[r.getName]);

                case ASTType.LITERAL:
                    const r = cast(Literal)rule;
                    return r.getLiteral();

                case ASTType.EOF:
                    return "";
            }
        }
}

unittest {
    import bnf.parser;
    {
        auto src = Source.fromString(`
<number> ::= <digit> | <digit> <number> ;
<digit> ::= "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" ;
`);
        const syntax = parseSyntax(src);
        import std.stdio;
        auto gen = new Generator(syntax);
        gen.setRnd(Random(0));
        assert (gen.generate("number") == "85247");
    }
    {
         auto src = Source.fromString(`
number = [ "-" ], digit, { digit };
digit = "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" ;
`);
        const syntax = parseSyntax(src);
        auto gen = new Generator(syntax);
        gen.setRnd(Random(0));
        assert (gen.generate("number") == "-1247");
    }
}
