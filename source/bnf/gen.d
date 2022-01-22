module bnf.gen;
import std.format;
import std.random;
import std.typecons : Rebindable;

import bnf.ast;

class Generator {
    private:
        Rebindable!(const AST)[string] rules;
        Random rnd;
        
    public:
        this(in Rule[] syntax) {
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
                case ASTType.REPEAT:
                    assert(0);

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
            }

        }
}

unittest {
    {
        import bnf.parser;

        auto src = Source.fromString(`
<number> ::= <digit> | <digit> <number>
<digit> ::= "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9"
`);
        const syntax = parseSyntax(src);

        import std.stdio;
        auto gen = new Generator(syntax);
        gen.setRnd(Random(0));

        assert (gen.generate("number") == "85247");
    }
}
