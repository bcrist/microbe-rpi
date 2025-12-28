source: [:0]const u8,
index: u32,
offset: u32,
type: Token_Type,
len: u32,

pub const Token_Type = enum {
    eof,
    unrecognized_character,
    linespace,
    newline,
    number,
    identifier,
    @":",
    @"::",
    @",",
    @".",
    @"~",
    @"+",
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
    @">>",
    @"!",
    @"!=",
};

pub fn init(source: []const u8) Lexer {
    var self: Lexer = .{
        .source = source,
        .index = 0,
        .offset = 0,
        .type = undefined,
        .len = undefined,
    };
    self.lex();
    return self;
}

fn lex(self: *Lexer) void {
    switch (self.source[self.offset]) {
        0 => {
            self.type = .eof;
            self.len = 0;
        },
        1...9, 11, 12, 14...' ' => {
            self.type = .linespace;
            var len = 1;
            while (switch (self.source[self.offset + len]) {
                1...9, 11, 12, 14 => true,
                else => false,
            }) len += 1;
        },
        '\r' => {
            self.type = .newline;
            self.len = if (self.source[self.offset + 1] == '\n') 2 else 1;
        },
        '\n' => {
            self.type = .newline;
            self.len = 1;
        },
        'A'...'Z', 'a'...'z' => {
        },
        '0' => {
        },
        '1'...'9' => {
        },
        else => {
            self.type = .unrecognized_character;
            self.len = 1;
        },
    }
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
