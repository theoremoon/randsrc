module bnf.parser;
import bnf.ast;

import std.file;
import std.ascii : isAlpha, isAlphaNum;
import std.uni : isWhite;
import std.format;
import std.typecons;

class ParseError : Exception
{
    this(string msg, Source src, string file = __FILE__, size_t line = __LINE__) {
        super("Parse Error: %s at source %s line %d".format(msg, src.path, src.line), file, line);
    }
}

struct Source {
    public:
        string src;
        string path;
        uint p;
        uint line;

        void skipWhite() {
            while (!this.eof && isWhite(this.peek)) {
                this.next();
            }
        }
        char peek() {
            return src[p];
        }
        char next() {
            if (src[p] == '\n') {
                this.line++;
            }
            return src[p++];
        }
        bool eof() {
            return p >= src.length;
        }
        bool isNext(in char c) {
            if (!this.eof && this.peek == c) {
                return true;
            }
            return false;
        }
        bool isNext(in string s) {
            foreach (i, c; s) {
                if (this.p + i >= this.src.length) {
                    return false;
                }
                if (this.src[this.p + i] != c) {
                    return false;
                }
            }
            return true;
        }

        void read(in char c) {
            if (!this.isNext(c)) {
                throw new ParseError("expected %c".format(c), this);
            }
            this.p++;
        }
        void read(in string s) {
            if (!this.isNext(s)) {
                throw new ParseError("expected %s".format(s), this);
            }
            this.p += s.length;
        }

        auto save() {
            return this.p;
        }
        void restore(uint p) {
            this.p = p;
        }

        static Source fromFile(string path) {
            return Source(readText(path), path, 0, 1);
        }
        static Source fromString(string src) {
            return Source(src, "<string>", 0, 1);
        }

        unittest {
            const src = Source.fromString("Hello");
            assert (src.src == "Hello");
            assert (src.path == "<string>");
            assert (src.p == 0);
            assert (src.line == 1);
        }
}

auto parseSyntax(ref Source src) {
    Rule[] rules = [];
    src.skipWhite();

    while (true) {
        auto rule = parseRule(src);
        if (rule is null) {
            break;
        }
        rules ~= rule;

        src.skipWhite();
    }
    return rules;
}
unittest {
    {
        auto src = Source.fromString(`
<syntax>         ::= <rule> | <rule> <syntax> ;
<rule>           ::= <opt-whitespace> "<" <rule-name> ">" <opt-whitespace> "::=" <opt-whitespace> <expression> <line-end> ;
<opt-whitespace> ::= " " <opt-whitespace> | "" ;
`);
        const syntax = parseSyntax(src);
        assert (syntax.length == 3);

        assert (syntax[0].name.toString() == "<syntax>");
        assert (syntax[0].expr.toString() == `<rule> | <rule> <syntax>`);
        assert (syntax[1].name.toString() == "<rule>");
        assert (syntax[1].expr.toString() == `<opt-whitespace> "<" <rule-name> ">" <opt-whitespace> "::=" <opt-whitespace> <expression> <line-end>`);
        assert (syntax[2].name.toString() == "<opt-whitespace>");
        assert (syntax[2].expr.toString() == `" " <opt-whitespace> | ""`);
    }
}

auto parseRule(ref Source src) {
    src.skipWhite();
    if (src.eof) {
        return null;
    }
    auto name = parseRuleName(src);
    if (name is null) {
        return null;
    }

    src.skipWhite();
    if (src.isNext("::=")) {
        src.read("::=");
    }
    else if (src.isNext('=')) {
        src.read('=');
    }
    else {
        throw new ParseError("\"::=\" or \"=\" is expected", src);
    }
    src.skipWhite();

    auto save = src.save;
    auto expr = src.parseExpression();
    if (expr is null) {
        src.restore(save);
        throw new ParseError("expression is expected", src);
    }

    if (!src.eof) {
        src.read(';');
    }

    return new Rule(name, expr);
}
unittest {
    {
        auto src = Source.fromString(`<rule> ::= <opt-whitespace> "<" <rule-name> ">" <opt-whitespace> "::=" <opt-whitespace> <expression> <line-end>`);
        const rule = parseRule(src);
        assert (rule.name.toString() == "<rule>");
        assert (rule.expr.toString() == `<opt-whitespace> "<" <rule-name> ">" <opt-whitespace> "::=" <opt-whitespace> <expression> <line-end>`);
    }
}

AST parseExpression(ref Source src) {
    return parseChoice(src);
}
unittest {
    {
        auto src = Source.fromString(`<list> | <list> <opt-whitespace> "|" <opt-whitespace> <expression>`);
        const expr = parseExpression(src);
        assert (expr.toString() == `<list> | <list> <opt-whitespace> "|" <opt-whitespace> <expression>`);
    }
    {
        auto src = Source.fromString(`field {fieldsep field} [fieldsep]`);
        const expr = parseExpression(src);
        assert (expr.toString() == `<field> { <fieldsep> <field> } [ <fieldsep> ]`);
    }
    {
        auto src = Source.fromString(`[ "-" ], digit, { digit }`);
        const expr = parseExpression(src);
        assert (expr.toString() == `[ "-" ] <digit> { <digit> }`);
    }
}

AST parseChoice(ref Source src) {
    src.skipWhite();
    auto expr = parseList(src);
    if (expr is null) {
        return null;
    }
    AST[] exprs = [expr];
    while (true) {
        src.skipWhite();
        if (!src.eof && src.isNext('|')) {
            src.read('|');
            src.skipWhite();
            auto list = parseList(src);
            if (list is null) {
                throw new ParseError("expression is expected", src);
            }
            exprs ~= list;
        }
        else {
            break;
        }
    }
    return new Choice(exprs);
}

AST parseList(ref Source src) {
    auto expr = parseParentheses(src);
    if (expr is null) {
        return null;
    }
    AST[] exprs = [expr];

    while (true) {
        if (src.eof) {
            break;
        }
        src.skipWhite();
        if (!src.eof && src.isNext(',')) {
            src.read(',');
            src.skipWhite();
        }
        auto paren = src.parseParentheses();
        if (paren is null) {
            break;
        }
        exprs ~= paren;
        src.skipWhite();
    }

    if (exprs.length == 1) {
        return exprs[0];
    }
    return new List(exprs);
}

AST parseParentheses(ref Source src) {
    src.skipWhite();
    if (src.eof) {
        return null;
    }

    if (src.isNext('[')) {
        src.read('[');
        auto expr = parseChoice(src);
        if (expr is null) {
            throw new ParseError("expression is expected", src);
        }
        src.skipWhite();
        src.read(']');
        return new Optional(expr);
    }
    else if (src.isNext('{')) {
        src.read('{');
        auto expr = parseChoice(src);
        if (expr is null) {
            throw new ParseError("expression is expected", src);
        }
        src.skipWhite();
        src.read('}');
        return new Repeat(expr);
    }
    else if (src.isNext('(')) {
        src.read('(');
        auto expr = parseChoice(src);
        if (expr is null) {
            throw new ParseError("expression is expected", src);
        }
        src.skipWhite();
        src.read(')');
        return expr;
    }

    auto term = parseTerm(src);
    if (term is null) {
        return null;
    }
    return term;
}


auto parseTerm(ref Source src) {
    auto literal = parseLiteral(src);
    if (literal !is null) {
        return literal;
    }

    auto ruleName = parseRuleName(src);
    if (ruleName !is null) {
        return ruleName;
    }

    return null;
}

AST parseRuleName(ref Source src) {
    if (src.peek == '<') {
        src.next();
        char[] buf = [];
        while (true) {
            if (src.eof) {
                throw new ParseError("unexpected EOF", src);
            }
            if (src.peek == '>') {
                src.next();
                return new RuleName(buf.idup);
            }
            buf ~= src.next();
        }
    }
    else if (isAlpha(src.peek)) {
        char[] buf = [];
        while (!src.eof && (isAlphaNum(src.peek) || src.peek == '_')) {
            buf ~= src.next();
        }
        return new RuleName(buf.idup);
    }
    return null;
}
unittest {
    {
        auto src = Source.fromString(`<rule1>`);
        auto ruleName = parseRuleName(src);
        assert (ruleName.toString == `<rule1>`);
    }
    {
        auto src = Source.fromString(`rule2`);
        auto ruleName = parseRuleName(src);
        assert (ruleName.toString == `<rule2>`);
    }
}

AST parseLiteral(ref Source src) {
    if (src.peek == '\'') {
        src.next();
        char[] buf = [];
        while (true) {
            if (src.eof) {
                throw new ParseError("unexpected EOF", src);
            }
            if (src.peek == '\'') {
                src.next();
                return new Literal(buf.idup);
            }
            buf ~= src.next();
        }
    }
    else if (src.peek == '"') {
        src.next();
        char[] buf = [];
        while (true) {
            if (src.eof) {
                throw new ParseError("unexpected EOF", src);
            }
            if (src.peek == '"') {
                src.next();
                return new Literal(buf.idup);
            }
            buf ~= src.next();
        }
    }
    return null;
}
unittest {
    {
        auto src = Source.fromString(`"literal"`);
        auto literal = parseLiteral(src);
        assert (literal.toString == `"literal"`);
    }
    {
        auto src = Source.fromString(`'literal'`);
        auto literal = parseLiteral(src);
        assert (literal.toString == `"literal"`);
    }
    {
        auto src = Source.fromString(`mogumogu`);
        auto literal = parseLiteral(src);
        assert (literal is null);
    }
    {
        import std.exception : assertThrown;

        auto src = Source.fromString(`"lit`);
        assertThrown(parseLiteral(src));
    }
}
