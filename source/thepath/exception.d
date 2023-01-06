/// module that contains exceptions generated by thepath lib
module thepath.exception;

private import std.exception;


/// PathException - will be raise on failure on path (or file) operations
class PathException : Exception {
    mixin basicExceptionCtors;
}



