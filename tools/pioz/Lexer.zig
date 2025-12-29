source: [:0]const u8,
index: u32,
offset: u32,
kind: Token_Kind,
len: u32,

pub const Token_Kind = enum {
    eof,
    unrecognized_character,
    linespace,
    newline,
    decimal,
    hex,
    octal,
    binary,
    identifier,
    @":",
    @"::",
    @",",
    @".",
    @"~",
    @"+",
    @"++",
    @"-",
    @"--",
    @"*",
    @"/",
    @";",
    @"//",
    @"%",
    @"{",
    @"}",
    @"(",
    @")",
    @"[",
    @"]",
    @"<",
    @"<<",
    @">",
    @">>",
    @"!",
    @"!=",

    pub fn is_number(self: Token_Kind) bool {
        return switch (self) {
            .decimal, .hex, .octal, .binary => true,
            else => false,
        };
    }
};

pub fn init(source: []const u8) Lexer {
    var self: Lexer = .{
        .source = source,
        .index = 0,
        .offset = 0,
        .kind = undefined,
        .len = undefined,
    };
    self.lex();
    return self;
}

fn lex(self: *Lexer) void {
    const offset = self.offset;
    switch (self.source[offset]) {
        0 => {
            self.kind = .eof;
            self.len = 0;
        },
        1...9, 11, 12, 14...' ' => {
            self.kind = .linespace;
            var len = 1;
            while (switch (self.source[offset + len]) {
                1...9, 11, 12, 14 => true,
                else => false,
            }) len += 1;
            self.len = len;
        },
        '\r' => {
            self.kind = .newline;
            self.len = if (self.source[offset + 1] == '\n') 2 else 1;
        },
        '\n' => {
            self.kind = .newline;
            self.len = 1;
        },
        'A'...'Z', 'a'...'z' => {
            self.kind = .identifier;
            var len = 1;
            while (switch (self.source[offset + len]) {
                'A'...'Z', 'a'...'z', '0'...'9', '_' => true,
                else => false,
            }) len += 1;
            self.len = len;
        },
        '0' => {
            var len = 2;
            switch (self.source[offset + 1]) {
                '0'...'9' => {
                    self.kind = .decimal;
                },
                'x', 'X' => {
                    self.kind = .hex;
                },
                'b', 'B' => {
                    self.kind = .binary;
                },
                'o', 'O' => {
                    self.kind = .octal;
                },
                else => {
                    self.kind = .decimal;
                    len = 1;
                },
            }
            while (switch (self.source[offset + len]) {
                '0'...'9', 'A'...'Z', 'a'...'z', '_' => true,
                else => false,
            }) len += 1;
            self.len = len;
        },
        '1'...'9' => {
            self.kind = .decimal;
            var len = 1;
            while (switch (self.source[offset + len]) {
                '0'...'9', 'A'...'Z', 'a'...'z', '_' => true,
                else => false,
            }) len += 1;
            self.len = len;
        },
        ':' => {
            if (self.source[offset + 1] == ':') {
                self.kind = .@"::";
                self.len = 2;
            } else {
                self.kind = .@":";
                self.len = 1;
            }
        },
        ',' => {
            self.kind = .@",";
            self.len = 1;
        },
        '.' => {
            self.kind = .@".";
            self.len = 1;
        },
        '~' => {
            self.kind = .@"~";
            self.len = 1;
        },
        '+' => {
            if (self.source[offset + 1] == '+') {
                self.kind = .@"++";
                self.len = 2;
            } else {
                self.kind = .@"+";
                self.len = 1;
            }
        },
        '-' => {
            if (self.source[offset + 1] == '-') {
                self.kind = .@"--";
                self.len = 2;
            } else {
                self.kind = .@"-";
                self.len = 1;
            }
        },
        '*' => {
            self.kind = .@"*";
            self.len = 1;
        },
        '/' => {
            if (self.source[offset + 1] == '/') {
                self.kind = .@"//";
                self.len = 2;
            } else {
                self.kind = .@"/";
                self.len = 1;
            }
        },
        ';' => {
            self.kind = .@";";
            self.len = 1;
        },
        '%' => {
            self.kind = .@"%";
            self.len = 1;
        },
        '{' => {
            self.kind = .@"{";
            self.len = 1;
        },
        '}' => {
            self.kind = .@"}";
            self.len = 1;
        },
        '(' => {
            self.kind = .@"(";
            self.len = 1;
        },
        ')' => {
            self.kind = .@")";
            self.len = 1;
        },
        '[' => {
            self.kind = .@"[";
            self.len = 1;
        },
        ']' => {
            self.kind = .@"]";
            self.len = 1;
        },
        '<' => {
            if (self.source[offset + 1] == '<') {
                self.kind = .@"<<";
                self.len = 2;
            } else {
                self.kind = .@"<";
                self.len = 1;
            }
        },
        '>' => {
            if (self.source[offset + 1] == '>') {
                self.kind = .@">>";
                self.len = 2;
            } else {
                self.kind = .@">";
                self.len = 1;
            }
        },
        '!' => {
            if (self.source[offset + 1] == '=') {
                self.kind = .@"!=";
                self.len = 2;
            } else {
                self.kind = .@"!";
                self.len = 1;
            }
        },
        else => {
            self.kind = .unrecognized_character;
            self.len = 1;
        },
    }
}

pub fn try_token(self: *Lexer, kind: Token_Kind) bool {
    if (self.kind == kind) {
        self.consume();
        return true;
    }
    return false;
}

pub fn try_keyword(self: *Lexer, kw: []const u8) bool {
    if (self.kind == .identifier and self.len == kw.len) {
        if (std.ascii.eqlIgnoreCase(kw, self.source[self.offset..][0..self.len])) {
            self.consume();
            return true;
        }
    }
    return false;
}

pub fn consume(self: *Lexer) void {
    self.index += 1;
    self.offset += self.len;
    self.lex();
}

pub fn snapshot(self: *Lexer) Snapshot {
    return .{
        .index = self.index,
        .offset = self.offset,
    };
}

pub fn reset(self: *Lexer, s: Snapshot) void {
    if (self.index != s.index) {
        self.index = s.index;
        self.offset = s.offset;
        self.lex();
    }
}

pub const Snapshot = struct {
    index: u32,
    offset: u32,
};

const Lexer = @This();

const std = @import("std");
