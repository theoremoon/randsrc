module bnf.ast;
import std.format;
import std.algorithm;
import std.conv : to;
import std.string;

enum ASTType {
    OPTIONAL,
    REPEAT,
    CHOICE,
    LIST,
    RULENAME,
    LITERAL,
    EOF,
}

abstract class AST {
    public:
        ASTType type() const;
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

class Optional : AST {
    private:
        AST rule;
    public:
        this(AST rule) {
            this.rule = rule;
        }
        override string toString() const {
            return "[ %s ]".format(this.rule.toString());
        }
        override ASTType type() const {
            return ASTType.OPTIONAL;
        }
        const(AST) getRule() const {
            return this.rule;
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
            return "{ %s }".format(this.rule.toString());
        }
        override ASTType type() const {
            return ASTType.REPEAT;
        }
        const(AST) getRule() const {
            return this.rule;
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
        override ASTType type() const {
            return ASTType.CHOICE;
        }
        const(AST[]) getChoices() const {
            return this.rules;
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
        override ASTType type() const {
            return ASTType.LIST;
        }
        const(AST[]) getRules() const {
            return this.rules;
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
        override ASTType type() const {
            return ASTType.RULENAME;
        }

        string getName() const {
            return this.name;
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
        override ASTType type() const {
            return ASTType.LITERAL;
        }

        string getLiteral() const {
            return this.s;
        }
}

class EOF : AST {
    public:
        override string toString() const {
            return "<EOF>";
        }
        override ASTType type() const {
            return ASTType.EOF;
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
