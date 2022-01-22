module bnf.ast;
import std.format;
import std.algorithm;
import std.conv : to;
import std.string;

abstract class AST {
    public:
        override string toString() const;
}

class Rule {
    public:
        AST name;
        AST expr;
        this(AST name, AST expr) {
            this.name = name;
            this.expr = expr;
        }
}

class Repeat : AST {
    private:
        AST rule;
    public:
        this(AST rule) {
            this.rule = rule;
        }
        override string toString() const {
            return "[%s]".format(this.rule.toString());
        }
}

class Choice : AST {
    private:
        AST[] rules;
    public:
        this(AST[] rules) {
            this.rules = rules;
        }
        override string toString() const {
            return this.rules.map!(to!string).join(" | ");
        }
}

class List : AST {
    private:
        AST[] rules;
    public:
        this(AST[] rules) {
            this.rules = rules;
        }
        override string toString() const {
            return this.rules.map!(to!string).join(" ");
        }
}

class RuleName : AST {
    private:
        string name;
    public:
        this(string name) {
            this.name = name;
        }
        override string toString() const {
            return "<%s>".format(this.name);
        }
}

class Literal : AST {
    private:
        string s;
    public:
        this(string s) {
            this.s = s;
        }
        override string toString() const {
            return "\"%s\"".format(this.s.replace("\"", "\\\""));
        }
}

unittest {
    const syntax = new Choice([
        new List([
            new Literal("\""), new RuleName("text1"), new Literal("\""),
        ]),
        new List([
            new Literal("'"), new RuleName("text2"), new Literal("'"),
        ]),
    ]);
    assert (syntax.toString() == `"\"" <text1> "\"" | "'" <text2> "'"`);
}
