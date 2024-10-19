//TODO: can I do comptime magic here?
pub const MinijinjaError = error{
    NonPrimitive,
    NonKey,
    InvalidOperation,
    SyntaxError,
    TemplateNotFound,
    TooManyArguments,
    MissingArgument,
    UnknownFilter,
    UnknownFunction,
    UnknownTest,
    UnknownMethod,
    BadEscape,
    UndefinedError,
    BadSerializtion,
    BadInclude,
    EvalBlock,
    CannotUnpack,
    WriteFailure,
    Unknown,
};

pub fn get_error_from_int(code: c_uint) MinijinjaError {
    const err = switch (code) {
        0 => MinijinjaError.NonPrimitive,
        1 => MinijinjaError.NonKey,
        2 => MinijinjaError.InvalidOperation,
        3 => MinijinjaError.SyntaxError,
        4 => MinijinjaError.TemplateNotFound,
        5 => MinijinjaError.TooManyArguments,
        6 => MinijinjaError.MissingArgument,
        7 => MinijinjaError.UnknownFilter,
        8 => MinijinjaError.UnknownFunction,
        9 => MinijinjaError.UnknownTest,
        10 => MinijinjaError.UnknownMethod,
        11 => MinijinjaError.BadEscape,
        12 => MinijinjaError.UndefinedError,
        13 => MinijinjaError.BadSerializtion,
        14 => MinijinjaError.BadInclude,
        15 => MinijinjaError.EvalBlock,
        16 => MinijinjaError.CannotUnpack,
        17 => MinijinjaError.WriteFailure,
        18 => MinijinjaError.Unknown,
        else => MinijinjaError.Unknown,
    };
    return err;
}
