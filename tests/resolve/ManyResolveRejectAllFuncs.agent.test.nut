/**
 * "Promise" symbol is injected dependency from ImpUnit_Promise module,
 * while class being tested can be accessed from global scope as "::Promise".
 */

// Case resolve - then(func, func) + fail(func) + finally()
class ManyResolveRejectAllFuncs extends ImpTestCase {
    middleOfRand = 1.0 * RAND_MAX / 2;

    function _verifyTrue(condition, result, addMsg) {
        if (!condition) {
            result[1] = addMsg + result[1];
            result[0] = false;
        }
    }

    /**
    * Perform a deep comparison of two values
    * @param {*} value1
    * @param {*} value2
    * @param {string} message
    * @param {boolean} isForwardPass - on forward pass value1 is treated "expected", value2 as "actual" and vice-versa on backward pass
    * @param {string} path - current slot path
    * @param {int} level - current depth level
    * @private
    */
    function _assertDeepEqualImpl(value1, value2, message, isForwardPass, path = "", level = 0) {
        local result = true;
        local cleanPath = @(p) p.len() == 0 ? p : p.slice(1);
        if (level > 32) {
            server.log("Possible cyclic reference at " + cleanPath(path));
            return false;
        }
        switch (type(value1)) {
            case "table":
            case "class":
            case "array":
                foreach (k, v in value1) {
                    path += "." + k;
                    if (!(k in value2)) {
                        server.log(format("%s slot [%s] in actual value",
                            isForwardPass ? "Missing" : "Extra", cleanPath(path)));
                        return false;
                    }
                    result = result && _assertDeepEqualImpl(value1[k], value2[k], message, isForwardPass, path, level + 1);
                }
                break;
            case "null":
                break;
            default:
                if (value2 != value1) {
                    server.log(format(message, cleanPath(path), value1 + "", value2 + ""));
                    return false;
                }
                break;
        }
        return result;
    }

    /**
    * Perform a deep comparison of two values
    * Useful for comparing arrays or tables
    * @param {*} expected
    * @param {*} actual
    * @param {string} message
    */
    function _assertDeepEqual(expected, actual, message = "At [%s]: expected \"%s\", got \"%s\"") {
        return _assertDeepEqualImpl(expected, actual, message, true) // forward pass
            && _assertDeepEqualImpl(actual, expected, message, false); // backwards pass
    }

    function _manyResolvingRejecting(isDelyed, values) {
        local promises = [];
        foreach (value in values) {
            promises.append(
                Promise(function(ok, err) {
                    // State mask
                    // 1 - resolve handler is called
                    // 2 - value is wrong in resolve handler
                    // 4 - reject handler is called
                    // 8 - value is wrong in reject handler
                    // 16 - fail handler is called
                    // 32 - value is wrong in fail handler
                    // 64 - finally handler is called
                    // 128 - value is wrong in finally handler
                    local iState = 0;
                    local myValue = value;
                    local strChain = "";
                    local cb = function (resolve, reject) { // many resolve/reject call
                        foreach (nextValue in values) {
                            local rnd = math.rand();
                            if (middleOfRand < rnd) {
                                strChain += "1";
                                resolve(nextValue);
                            } else {
                                strChain += "0";
                                reject(nextValue);
                            }
                        }
                    }.bindenv(this);
                    local p = ::Promise(function (resolve, reject) {
                        if (isDelyed) { // delayed resolving
                            imp.wakeup(0.1, function () {
                                resolve(myValue);
                                cb(resolve, reject); // many resolve/reject call
                            }.bindenv(this));
                        } else { // basic resolving
                            resolve(myValue);
                            cb(resolve, reject); // many resolve/reject call
                        }
                    }.bindenv(this));
                    p.then(function(res) { 
                        iState = iState | 1; // 1 - resolve handler is called
                        if (_assertDeepEqual(myValue, res, "Resolve handler - wrong value, value=" + res)) {
                            iState = iState | 2; // 2 - value is wrong in resolve handler
                        }
                    }.bindenv(this), function(res) { 
                        iState = iState | 4; // 4 - reject handler is called
                        if (_assertDeepEqual(myValue, res, "Reject handler - wrong value, value=" + res)) {
                            iState = iState | 8; // 8 - value is wrong in reject handler
                        }
                    }.bindenv(this));
                    p.fail(function(res) { 
                        iState = iState | 16; // 16 - fail handler is called
                        if (_assertDeepEqual(myValue, res, "Fail handler - wrong value, value=" + res)) {
                            iState = iState | 32; // 32 - value is wrong in fail handler
                        }
                    }.bindenv(this));
                    p.finally(function(res) {
                        iState = iState | 64; // 64 - finally handler is called
                        if (_assertDeepEqual(myValue, res, "Finally handler - wrong value, value=" + res)) {
                            iState = iState | 128; // 128 - value is wrong in finally handler
                        }
                    }.bindenv(this));                    // at this point Promise should not be resolved as it's body is handled in imp.wakeup(0)
                    assertEqual(0, iState, "The Promise should not be resolved strict after the promise declaration");
                    // now it should be resolved
                    imp.wakeup(1, function() {
                        local result = [true, "Value='" + myValue + "', iState=" + iState+", RND=" + strChain];
                        _verifyTrue(iState & 1, result, "Resolve handler is not called. ");
                        _verifyTrue(iState & 2, result, "Value is wrong in resolve handler. ");
                        _verifyTrue(iState & 64, result, "Finally handler is not called. ");
                        _verifyTrue(iState & 128, result, "Value is wrong in finally handler. ");
                        if (iState & 0X3C) { // 0011 1100 = 0X3C
                            err("Failed: unexpected handler call. " + result[1]);
                        } else if (result[0]) { // 0011 1100 = 0X3C
                            ok("Passed: " + result[1]);
                        } else {
                            err("Failed: " + result[1]);
                        }
                    }.bindenv(this));
                }.bindenv(this))
            );
        }
        return Promise(function(ok, err) {
            ::Promise.all(promises).then(ok, err);
        }.bindenv(this));
    }

    /**
     * Test resolving with many resolve/reject call
     */
    function testBasicResolving_1() {
        return _manyResolvingRejecting(false, [true, false]);
    }

    function testBasicResolving_2() {
        return _manyResolvingRejecting(false, [0, 1]);
    }

    function testBasicResolving_3() {
        return _manyResolvingRejecting(false, [-1, ""]);
    }

    function testBasicResolving_4() {
        return _manyResolvingRejecting(false, ["tmp", 0.001]);
    }

    function testBasicResolving_5() {
        return _manyResolvingRejecting(false, [0.0, -0.001]);
    }

    function testBasicResolving_6() {
        return _manyResolvingRejecting(false, [regexp(@"(\d+) ([a-zA-Z]+)(\p)"), null]);
    }

    function testBasicResolving_7() {
        return _manyResolvingRejecting(false, [blob(4), array(5)]);
    }

    function testBasicResolving_8() {
        return _manyResolvingRejecting(false, [{
            firstKey = "Max Normal", 
            secondKey = 42, 
            thirdKey = true
        }, function() {
            return 15;
        }]);
    }

    function testBasicResolving_9() {
        return _manyResolvingRejecting(false, [class {
            tmp = 0;
            constructor(){
                tmp = 15;
            }
        }, server]);
    }

    /**
     * Test delayed resolving with many resolve/reject call
     */
    function testDelayedResolving_1() {
        return _manyResolvingRejecting(true, [true, false]);
    }

    function testDelayedResolving_2() {
        return _manyResolvingRejecting(true, [0, 1]);
    }

    function testDelayedResolving_3() {
        return _manyResolvingRejecting(true, [-1, ""]);
    }

    function testDelayedResolving_4() {
        return _manyResolvingRejecting(true, ["tmp", 0.001]);
    }

    function testDelayedResolving_5() {
        return _manyResolvingRejecting(true, [0.0, -0.001]);
    }

    function testDelayedResolving_6() {
        return _manyResolvingRejecting(true, [regexp(@"(\d+) ([a-zA-Z]+)(\p)"), null]);
    }

    function testDelayedResolving_7() {
        return _manyResolvingRejecting(true, [blob(4), array(5)]);
    }

    function testDelayedResolving_8() {
        return _manyResolvingRejecting(true, [{
            firstKey = "Max Normal", 
            secondKey = 42, 
            thirdKey = true
        }, function() {
            return 15;
        }]);
    }

    function testDelayedResolving_9() {
        return _manyResolvingRejecting(true, [class {
            tmp = 0;
            constructor(){
                tmp = 15;
            }
        }, server]);
    }
}
