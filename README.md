<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->


- [Promise Class 2.0.0-dev](#promise-class-110)
  - [Usage](#usage)
    - [Promise()](#promise)
    - [.then()](#then)
    - [.fail()](#fail)
    - [.finally()](#finally)
    - [Promise.loop()](#promiseloop)
    - [Promise.serial()](#promiseserial)
  - [Example](#example)
  - [Testing](#testing)
    - [TL;DR](#tldr)
    - [Running Tests](#running-tests)
  - [Development](#development)
- [License](#license)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

<br />

[![Build Status](https://travis-ci.org/electricimp/Promise.svg?branch=develop)](https://travis-ci.org/electricimp/Promise)

# Promise Class 2.0.0-dev

This Promise class is based on the PromiseJS definition at:
https://www.promisejs.org/implementing/

According to Wikipedia, "Futures and promises originated in functional programming and
related paradigms (such as logic programming) to decouple a value (a future) from how
it was computed (a promise), allowing the computation to be done more flexibly, notably
by parallelizing it."

This Promise class implements a subset of the generic Promise concept by
providing two callback functions, then() and fail(). then() is executed when the
promise is successfully completed, fail() is executed when the promise is completed
with any sort of detectible failure. Usually, an instantiated Promise object is
returned from a class instead of offering direct callback functions. This uniform
implementation makes the code clearer and easier to read.

**To add this library to your project, add `#require "promise.class.nut:2.0.0-dev"` to the top of your device code.**

You can view the library's source code on [GitHub](https://github.com/electricimp/Promise/tree/v2.0.0-dev).

## Usage

### Promise()

`Promise(actionFunction)`

The constructor should receive a single function, which will be executed to determine the final value and result. The actionFunction should receive two function parameters. Exactly one of these functions (`fulfill` or `reject`) should be executed at the completing of the actionFunction. If `fulfill` is executed then the success function will be called asynchronously; if `reject` is executed then the fail function will be called asynchronously.

### .then()

`.then(successFunction [,failFunction])`

This function allows the developer to provide a success function and optionally a fail function. The success function should accept a single parameter, the result; the fail function should accept a single parameter, the error.

### .fail()

`.fail(failFunction)`

This function allows the developer to provide a failure function. The failure function should accept a single parameter, the error.

### .finally()

`.finally(alwaysFunction)`

This function allows the developer to provide a function that is executed once the promise is resolved or rejected, regardless of the success/failure. Accepts a single parameter – result or error.

### Promise.loop()

`Promise.loop(compareFunction, nextFunction)`

A way to perform while loops with asynchronous processes.

Stops on `compareFunction() == false` or first rejection of looped _Promise_'s.

Returns _Promise_ that is resolved/rejected with the last value that come from looped _Promise_ when loop finishes.

For example in the following code `p` resolves with value "counter is 3" in 9 seconds.

```squirrel
local i = 0;
local p = Promise.loop(
    @() i++ < 3,
    function () {
        return Promise(function (resolve, reject) {
            imp.wakeup(3, function() {
                resolve("counter is " + i);
            });
        });
    }
);
```


### Promise.serial()

`Promise.serial(promises)`

Returns _Promise_ that resolves when all promises in chain resolve or when the first one rejects.

For example in the following code `p` rejects with value "2" in 2 seconds:

```squirrel
local promises = [
    Promise(@(resolve, reject) imp.wakeup(1, @() resolve(1))),
    Promise(@(resolve, reject) imp.wakeup(1, @() reject(2))),
    Promise(@(resolve, reject) imp.wakeup(1, @() resolve(3)))
];

local p = Promise.serial(promises);
```

## Example

An example implementation of a promise is:

```squirrel
class Widget {

    function _longTask(data, callback) {
        // Some long asynchronous task which calls callback at the end
    }

    function calculate(input) {
        return Promise(function (fulfill, reject) {
            _longTask(input, function (err, res) {
                if (err) {
                    reject(err);
                } else {
                    fulfill(res);
                }
            }.bindenv(this));
        }.bindenv(this));
    }
}
```

An example execute of this class and promise is:

```squirrel
Widget().calculate(123)
        .then(
            function(res) {
                server.log("Success: " + res)
            }.bindenv(this)
        )
        .fail(
            function(err) {
                server.error("Failed: " + err)
            }.bindenv(this)
        )
        .finally(
            function(r) {
                server.log("I'm always called")
            }.bindenv(this)
        )
```

## Testing

Repository contains [impUnit](https://github.com/electricimp/impUnit) tests and a configuration for [impTest](https://github.com/electricimp/impTest) tool.

### TL;DR

```bash
cp .imptest .imptest-local
nano .imptest-local # edit device/model
imptest test -c .imptest-local
```

### Running Tests

Tests can be launched with:

```bash
imptest test
```

By default configuration for the testing is read from [.imptest](https://github.com/electricimp/impTest/blob/develop/docs/imptest-spec.md).

To run test with your settings (for example while you are developing), create your copy of **.imptest** file and name it something like **.imptest.local**, then run tests with:

 ```bash
 imptest test -c .imptest.local
 ```

Tests will run with any imp.


## Development

This repository uses [git-flow](http://jeffkreeftmeijer.com/2010/why-arent-you-using-git-flow/).
Please make your pull requests to the __develop__ branch.

# License

The Promise class is licensed under the [MIT License](./LICENSE.txt).
