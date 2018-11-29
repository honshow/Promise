[![Build Status](https://travis-ci.org/electricimp/Promise.svg?branch=master)](https://travis-ci.org/electricimp/Promise)

# Promise

The library provides an implementation of promises for Electric Imp platform in Squirrel.

According to Wikipedia:
```
Futures and promises originated in functional programming and related paradigms (such as logic programming) to decouple a value (a future) from how it was computed (a promise), allowing the computation to be done more flexibly, notably by parallelizing it.
```

For more information on the concept of promises,
see the following references for Javascript implementation:

- [Promises/A+](https://promisesaplus.com/)
- [JavaScript Promises: There and back again](http://www.html5rocks.com/en/tutorials/es6/promises/)
- [Promise - Javascript](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise)

Promise APIs in Squirrel extend that of the JavaScript implementation.
The library introduces some new methods that don't exist in the original JavaScript implementation. For example:
- [Promise.race](Promise.race(*series*))
- [Promise.loop](Promise.loop(*continueFunction, nextFunction*))
- [Promise.serial](Promise.serial(*series*))

**NOTE**: To add this library to your project, add `#require "Promise.lib.nut:4.0.0"` to the top of your agent and/or device code.

## Class Usage

### Constructor: Promise(*actionFunction*)

The constructor should receive a single function, which will be executed to determine the final value and result.
The function passed into *actionFunction* requires two parameters of its own, *resolve* and *reject*, both of which
are themselves function references. Exactly one of these functions should be executed at the completion of the
*actionFunction*:

- `function resolve([value])` &mdash; calling *resolve()* sets Promise state as resolved and calls success handlers (passed as first argument of *.then()*)
- `function reject([reason])` &mdash; calling *reject()* sets Promise state as rejected and calls *.fail()* handlers

```squirrel
#require "Promise.lib.nut:4.0.0"

myPromise <- Promise(myActionFunction);
```

**NOTE**: The action fuction is executed alone with the Promise being instantiated. It's not delayed in time.

## Instance Methods

### then(*[onFulfilled, onRejected]*)

The *then()* method allows the developer to provide an *onFulfilled* function and/or an *onRejected* function.
Default handlers will be used if no parameters are passed in.

**NOTE:** To pass in an *onRejected* function only, you must pass in `null`
as the first parameter and the *onRejected* function as the second parameter or use
the [fail](fail(*onRejected*)) instead.

This method returns a *Promise* object to allow for method chaining.

```squirrel
myPromise
    .then(function(value) {
        server.log("myPromise resolved with value: " + value);
    }, function(reason) {
        server.log("myPromise rejected for reason: " + reason);
    });
```

Promises which reject with reasons will have their *onRejected* handlers called with that reason.
Promises which resolve with values will have their *onFulfilled* handler called with that value.
Calls to *then()* return promises, so a handler function (either *onFulfilled* or *onRejected*)
registered in *then()* which returns a value will pass this value on to the next *onFulfilled*
handler in the chain, and any exceptions throw by a handler will be passed on to the next available
*onRejected* handler. In this way errors can be caught and handled or thrown again, much like with
Squirrel’s `try` and `catch`. The following example is for demonstration only and is overly verbose.

```squirrel
// 'name' is a variable that *should* contain a string, but may not be

Promise.resolve(name)
    .then(function(name) {
        if (typeof name != "string") {
            throw "Invalid name";
        } else {
            // 'name' is valid, so just pass it through
            return name;
        }
    }, null)

    .then(null, function(reason) {
        // I run with reason == "invalid name"
        // So handle invalid name by providing a default
        return "Bob";
    })

    .then(function(name) {
        // I have a valid name
    });
```

Passing `null` as a handler corresponds to the default behaviour of passing any values
through to the next available *onFulfilled* handler, or throwing exceptions throwing
to the next available *onRejected* handler.

**NOTE:** Just as if no *onFulfilled* handlers are registered the last value returned will
be ignored, if no *onRejected* handlers are registered any exceptions that occur within a
promise executor or handler function will **not** be caught and are be ignored.
An "Unhandled promise rejection" warning is generated by the library in this case.

It is prudent to always add the following line at the end of your promise chains:

```squirrel
.fail(server.error.bindenv(server));
```

**NOTE:** The `Promise` instance object, `then` is called on may already have
been resolved or rejected. In this case the `onFulfilled` or `onRejected` handler
will be called immediately.

### fail(*onRejected*)

The *fail()* method allows the developer to provide an *onRejection* function.
This call is quivalent to `.then(null, onRejected)`.

```squirrel
myPromise
    .then(successHandler)
    .fail(function(reason) {
        server.log("myPromise rejected for reason OR successHandler through exception: " + reason);
    });
```

### finally(*alwaysFunction*)

The *finally()* method allows the developer to provide a function that is executed
both on resolve and rejection (ie. when the promise is *settled*). This call is quivalent
to `.then(alwaysFunction, alwaysFunction)`. The *alwaysFunction* accepts one prameter: result or error.

```squirrel
myPromise
    .finally(function(valueOrReason) {
        server.log("myPromise resolved or rejected with value or reason: " +  valueOrReason);
    });
```

## Class Methods

### Promise.resolve(*value*)

This method returns a promise that immediately resolves to a given value.

```squirrel
Promise.resolve(value)
    .then(function(value) {
        // Operate on value
    });
```

### Promise.reject(*reason*)

This method returns a promise that immediately rejects with a given reason.

```squirrel
Promise.reject(reason)
    .fail(function(reason) {
        // Operate on reason
    });
```

### Promise.all(*series*)

This method executes promises in parallel and resolves when they are all done.
It Returns a promise that resolves with an array of the resolved promise value
or rejects with first rejected paralleled promise value.

The parameter *series* is an array of promises and/or functions that return promises.

For example, in the following code *p* resolves with value `[1, 2, 3]` in 1.5 seconds:

```squirrel
local series = [
    Promise(
        function(resolve, reject) {
            imp.wakeup(1, function() {resolve(1)})
        }
    ),
    Promise(
        function(resolve, reject) {
            imp.wakeup(1.5, function() {resolve(2)})
        }
    ),
    Promise(
        function(resolve, reject) {
            imp.wakeup(0.5, function() {resolve(3)})
        }
    )
];

local p = Promise.all(series);
p.then(
    function(values) {
        // values == [1, 2, 3]
        foreach (a in values) {
            server.log(a);
        }
    }
);
```

### Promise.race(*series*)

This method executes promises in parallel and resolves when the first is done.
It returns a promise that resolves or rejects with the first resolved/rejected promise value.

The parameter *series* is an array of promises and/or functions that return promises.

For example, in the following code *p* rejects with value `"3"` in 0.5 second:

```squirrel
local promises = [
    // rejects first as the other one with 1s timeout
    // starts later from inside .race()
    Promise(
        function(resolve, reject) {
            imp.wakeup(1,
                function() {
                    reject(1);
                }
            )
        }
    ),
    function() {
        return Promise(
            function(resolve, reject) {
                imp.wakeup(1.5,
                    function() {
                        resolve(2);
                    }
                )
            }
        )
    },
    function() {
        return Promise(
            function(resolve, reject) {
                imp.wakeup(0.5,
                    function() {
                        reject(3);
                    }
                )
            }
        )
    }
];

local p = Promise.race(promises);
p.then(function(value) {
        // Not run
    }, function(reason) {
        // reason == 1
    });
```

### Promise.loop(*continueFunction, nextFunction*)

This method provides a way to perform `while` loops with asynchronous processes. It takes the following parameters:

- *continueFunction* &mdash; a function that returns `true` to continue the loop or `false` to stop it
- *nextFunction* &mdash; a function that returns next promise in the loop

The loop stops on `continueFunction() == false` or first rejection of looped promises.

*loop()* returns a promise that is resolved/rejected with the last value that comes from the looped promise when the loop finishes.

For example, in the following code *p* resolves with value `"counter is 3"` in 9 seconds.

```squirrel
local i = 0;
local p = Promise.loop(
    @() i++ < 3,
    function () {
        return Promise(function (resolve, reject) {
            imp.wakeup(3, function() {
                resolve("Counter is " + i);
            });
        });
    });
```

### Promise.serial(*series*)
**Args**: Array of promises and/or promise-returning functions
**Returns**: Promise

This method returns a promise that resolves when all the promises in the chain resolve or when the first one rejects.

The action function is triggered at the moment when the Promise instance is created. So using functions returning Promise instances to pass into `Promise.serial` makes instantiation sequential. I.e. a promise is created and the action is triggered only when the previous Promise in the series got resolved or rejected.

For example, in the following code `p` resolves with value `"3"` in 2.5 seconds
(the second function-argument is executed only when the first Promise resolves and the second one is instantiated):

```squirrel
local series = [
    Promise(
        function(resolve, reject) {
            imp.wakeup(1,
                function() {
                    resolve(1)
                }
            )
        }
    ),
    function() {
        return Promise(
            function(resolve, reject) {
                imp.wakeup(1.5,
                    function() {
                        resolve(2)
                    }
                )
            }
        )
    },
    Promise(
        function(resolve, reject) {
            imp.wakeup(0.5,
                function() {
                    resolve(3)
                }
            )
        }
    )
];

local p = Promise.serial(series);
```

While in the following code p resolves in 1.5 seconds with value `"3"` as all the Promises are instantiated at the same time:

```squirrel
local series = [
    Promise(
        function(resolve, reject) {
            imp.wakeup(1,
                function() {
                    resolve(1)
                }
            )
        }
    ),
    Promise(
        function(resolve, reject) {
            imp.wakeup(1.5,
                function() {
                    resolve(2)
                }
            )
        }
    ),
    Promise(
        function(resolve, reject) {
            imp.wakeup(0.5,
                function() {
                    resolve(3)
                }
            )
        }
    )
];

local p = Promise.serial(series);
```

## Recommended Use

Execution of multiple promises available in two modes: synchronous (one by one) or asynchronous (parallel execution). And this library provides several methods for both.

#### Synchronous

* `then`  
   Chain of `then` handlers is a classic way to organize serial execution. Each action passes result of execution to the next one. If current promise in chain was rejected, execution stops and `fail` handler triggered.  

   Useful when we need to pass data from one step to the next one. For example for smart weather station we need to read temperature data from sensor and send it from agent. We code will looks like this:

   ```squirrel
    function initSensor() {
        // some code, return promise
    }

    function readData(sensorId) {
        // return temperature value
    }

    initSensor()
    .then(function(sensorId) {
        return readData(sensorId);
    })
    .then(function(temp) {
        agent.send("temp", temp);
    })
    .fail(function(err) {
        server.log("Unexpected error: " + err);
    });
   ```

   Examples: [Then](./examples/example-then.nut)

* `serial(series)`  
   Executes actions in exact listed order, but without passing result from one step to another. Returns Promise, so
   when all chain of actions were executed, result of the last action will be passed to `then` handler. If any of
   events failed, `fail` handler triggered. 

   For example if we need to check for updates of new firmware. If current action fired, it means previous step was
   completed with success. Method install returns version of installed software update (for example 0.57). So when all steps are passed, `then` triggered:

    ```squirrel
    local series = [
        connect,
        checkUpdates,
        download,
        install
    ];

    Promise.serial(series);
    .then(function(ver) {
        server.log("Installed version: " + ver); // Installed version: 0.57
    })
    .fail(function(err) {
        server.log("Error: " + err);
    })
    ```

    Examples: [Serial](./examples/example-serial.nut)

* `loop(counterFunction, callback)`  
   This method executes callback returning a promise every iteration, while counterFunction returns `true`. Returns result of last executed promise.

   For example we can use `loop` to check doors sensors in the building to be sure all are closed, pinging them one by 
   one. We have method `checkDoorById()` that checks specified sensor by id and returns Promise. If during the loop 
   returned rejected promise, execution aborted and `fail` handler triggered.

    ```squirrel
    function checkDoorById (id) {
        // some code, returns promise
    }

    local i = 1;
    Promise.loop(
        @() i++ < 6,
        function () {
            return checkDoorById(i);
        }
    )
    .then(function(x) {
        server.log("All doors are closed");
    })
    .fail(function(err) {
        server.log("Unlocked door detected!");
    });
    ```

    Examples: [Loop](./examples/example-loop.nut)

#### Asynchronous

There are two main methods to execute multiple promises in parallel mode:

* `all(series)`  
   This method executes promises in parallel and resolves when they are all done. It returns a promise that resolves with an array of the resolved promise value or rejects with first rejected paralleled promise value.  
   
   For example on our smart weather station we need to read metrics from multiple sensors, then send it to server. Method `all` returns promise and it resolved only when all metrics are collected:

    ```squirrel
    Promise.all([getTemperature, getBarometer, getHumidity])
    .then(function(metrics) {
        agent.send("weather metrics", metrics);
    });
    ``` 

    Examples: [All](./examples/example-all.nut)

* `race(series)`  
   This method executes multiple promises in parallel and resolves when the first is done. Returns a promise that resolves or rejects with the first resolved/rejected promise value.  

   **NOTE:** Execution of declared promise starts imidately and execution of promises from functions starts only
   after `race` call. So not recommended to mix promise-returning functions and promises in `race` argument.

   For example if we writing code for some parking assistance software, there are 3 parkings near the building and
   we want to find free place for a car. Each parking has its own software API and we have different methods to request each of them. Now we call this 3 methods in parallel by `race` call and it returns Promise. As soon as any method will find a place, `then` handler will be triggered: 

    ```squirrel
    Promise.race([checkParkingA, checkParkingB, checkParkingC])
    .then(function(place) {
        server.log("Found place: " + place); // Found place: B11
    });
    .fail(function(err) {
        server.log("Sorry, all parkings are busy now");
    });
    ```

    Examples: [Race](./examples/example-race.nut)

## Testing

Repository contains [impt](https://github.com/electricimp/imp-central-impt) tests. Please refer to the
[imp test](https://github.com/electricimp/imp-central-impt/blob/master/TestingGuide.md) documentation for more details.

Tests will run with any imp.

## Examples

- [example a](./examples/example-a.nut)
- [example b](./examples/example-b.nut)
- [example c](./examples/example-c.nut)
- [example of sync series](./examples/example-sync-series.nut)
- [example of async series](./examples/example-async-series.nut)

## License

The Promise class is licensed under the [MIT License](./LICENSE.txt).
