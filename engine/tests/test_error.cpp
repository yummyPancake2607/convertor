#include <convertor/error.hpp>
#include <cassert>
#include <iostream>

using namespace convertor;
using namespace std;

void test_error_code() {
    Error ok;
    assert(ok.ok());
    assert(ok.code() == ErrorCode::kOk);

    Error err(ErrorCode::kFileNotFound, "File not found");
    assert(!err.ok());
    assert(err.code() == ErrorCode::kFileNotFound);
    assert(err.message() == "File not found");

    Result<int> r1(42);
    assert(r1.ok());
    assert(r1.value() == 42);

    Result<int> r2(Error(ErrorCode::kInternal, "fail"));
    assert(!r2.ok());
    assert(r2.error().code() == ErrorCode::kInternal);
    assert(r2.value_or(0) == 0);

    Result<void> v;
    assert(v.ok());

    Result<void> ve(Error(ErrorCode::kInternal, "err"));
    assert(!ve.ok());
}
