# @version ^0.3.7
"""
@title Standard Mathematical Utility Functions
@license GNU Affero General Public License v3.0
@author pcaversaccio
@custom:coauthor bout3fiddy
@notice These functions implement standard mathematical utility
        functions that are missing in the Vyper language. If a
        function is inspired by an existing implementation, it
        is properly referenced in the function docstring. The
        following functions have been added for convenience:
        - `uint256_average` (`external` `pure` function),
        - `int256_average` (`external` `pure` function),
        - `ceil_div` (`external` `pure` function),
        - `is_negative` (`external` `pure` function),
        - `mul_div` (`external` `pure` function),
        - `log_2` (`external` `pure` function),
        - `log_10` (`external` `pure` function),
        - `log_256` (`external` `pure` function),
        - `wad_ln` (`external` `pure` function),
        - `wad_exp` (`external` `pure` function),
        - `cbrt` (`external` `pure` function),
        - `wad_cbrt` (`external` `pure` function),
        - `_log_2` (`internal` `pure` function),
        - `_wad_cbrt` (`internal` `pure` function).
"""


@external
@payable
def __init__():
    """
    @dev To omit the opcodes for checking the `msg.value`
         in the creation-time EVM bytecode, the constructor
         is declared as `payable`.
    """
    pass


@external
@pure
def uint256_average(x: uint256, y: uint256) -> uint256:
    """
    @dev Returns the average of two 32-byte unsigned integers.
    @notice Note that the result is rounded towards zero. For
            more details on finding the average of two unsigned
            integers without an overflow, please refer to:
            https://devblogs.microsoft.com/oldnewthing/20220207-00/?p=106223.
    @param x The first 32-byte unsigned integer of the data set.
    @param y The second 32-byte unsigned integer of the data set.
    @return uint256 The 32-byte average (rounded towards zero) of
            `x` and `y`.
    """
    return unsafe_add(x & y, shift(x ^ y, -1))


@external
@pure
def int256_average(x: int256, y: int256) -> int256:
    """
    @dev Returns the average of two 32-byte signed integers.
    @notice Note that the result is rounded towards infinity.
            For more details on finding the average of two signed
            integers without an overflow, please refer to:
            https://patents.google.com/patent/US6007232A/en.
    @param x The first 32-byte signed integer of the data set.
    @param y The second 32-byte signed integer of the data set.
    @return int256 The 32-byte average (rounded towards infinity)
            of `x` and `y`.
    """
    return unsafe_add(unsafe_add(shift(x, -1), shift(y, -1)), x & y & 1)


@external
@pure
def ceil_div(x: uint256, y: uint256) -> uint256:
    """
    @dev Calculates "ceil(x / y)" for any strictly positive `y`.
    @notice The implementation is inspired by OpenZeppelin's
            implementation here:
            https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/Math.sol.
    @param x The 32-byte numerator.
    @param y The 32-byte denominator.
    @return uint256 The 32-byte rounded up result of "x/y".
    """
    assert y != empty(uint256), "Math: ceil_div division by zero"
    if (x == empty(uint256)):
        return empty(uint256)
    else:
        return unsafe_add(unsafe_div(x - 1, y), 1)


@external
@pure
def is_negative(x: int256) -> bool:
    """
    @dev Returns `True` if a 32-byte signed integer is negative.
    @notice Note that this function returns `False` for 0.
    @param x The 32-byte signed integer variable.
    @return bool The verification whether `x` is negative or not.
    """
    return (x ^ 1 < empty(int256))


@external
@pure
def mul_div(x: uint256, y: uint256, denominator: uint256, roundup: bool) -> uint256:
    """
    @dev Calculates "(x * y) / denominator" in 512-bit precision,
         following the selected rounding direction.
    @notice The implementation is inspired by Remco Bloemen's
            implementation under the MIT license here:
            https://xn--2-umb.com/21/muldiv.
            Furthermore, the rounding direction design pattern is
            inspired by OpenZeppelin's implementation here:
            https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/Math.sol.
    @param x The 32-byte multiplicand.
    @param y The 32-byte multiplier.
    @param denominator The 32-byte divisor.
    @param roundup The Boolean variable that specifies whether
           to round up or not. The default `False` is round down.
    @return uint256 The 32-byte calculation result.
    """
    # Handle division by zero.
    assert denominator != empty(uint256), "Math: mul_div division by zero"

    # 512-bit multiplication "[prod1 prod0] = x * y".
    # Compute the product "mod 2**256" and "mod 2**256 - 1".
    # Then use the Chinese Remainder theorem to reconstruct
    # the 512-bit result. The result is stored in two 256-bit
    # variables, where: "product = prod1 * 2**256 + prod0".
    mm: uint256 = uint256_mulmod(x, y, max_value(uint256))
    # The least significant 256 bits of the product.
    prod0: uint256 = unsafe_mul(x, y)
    # The most significant 256 bits of the product.
    prod1: uint256 = empty(uint256)

    if (mm < prod0):
        prod1 = unsafe_sub(unsafe_sub(mm, prod0), 1)
    else:
        prod1 = unsafe_sub(mm, prod0)

    # Handling of non-overflow cases, 256 by 256 division.
    if (prod1 == empty(uint256)):
        if (roundup and uint256_mulmod(x, y, denominator) != empty(uint256)):
            # Calculate "ceil((x * y) / denominator)". The following
            # line cannot overflow because we have the previous check
            # "(x * y) % denominator != 0", which accordingly rules out
            # the possibility of "x * y = 2**256 - 1" and `denominator == 1`.
            return unsafe_add(unsafe_div(prod0, denominator), 1)
        else:
            return unsafe_div(prod0, denominator)

    # Ensure that the result is less than 2**256. Also,
    # prevents that `denominator == 0`.
    assert denominator > prod1, "Math: mul_div overflow"

    #######################
    # 512 by 256 Division #
    #######################

    # Make division exact by subtracting the remainder
    # from "[prod1 prod0]". First, compute remainder using
    # the `uint256_mulmod` operation.
    remainder: uint256 = uint256_mulmod(x, y, denominator)

    # Second, subtract the 256-bit number from the 512-bit
    # number.
    if (remainder > prod0):
        prod1 = unsafe_sub(prod1, 1)
    prod0 = unsafe_sub(prod0, remainder)

    # Factor powers of two out of the denominator and calculate
    # the largest power of two divisor of denominator. Always `>= 1`,
    # unless the denominator is zero (which is prevented above),
    # in which case `twos` is zero. For more details, please refer to:
    # https://cs.stackexchange.com/q/138556.

    # The following line does not overflow because the denominator
    # cannot be zero at this stage of the function.
    twos: uint256 = denominator & (unsafe_add(~denominator, 1))
    # Divide denominator by `twos`.
    denominator_div: uint256 = unsafe_div(denominator, twos)
    # Divide "[prod1 prod0]" by `twos`.
    prod0 = unsafe_div(prod0, twos)
    # Flip `twos` such that it is "2**256 / twos". If `twos` is zero,
    # it becomes one.
    twos = unsafe_add(unsafe_div(unsafe_sub(empty(uint256), twos), twos), 1)

    # Shift bits from `prod1` to `prod0`.
    prod0 |= unsafe_mul(prod1, twos)

    # Invert the denominator "mod 2**256". Since the denominator is
    # now an odd number, it has an inverse modulo 2**256, so we have:
    # "denominator * inverse = 1 mod 2**256". Calculate the inverse by
    # starting with a seed that is correct for four bits. That is,
    # "denominator * inverse = 1 mod 2**4".
    inverse: uint256 = unsafe_mul(3, denominator_div) ^ 2

    # Use Newton-Raphson iteration to improve accuracy. Thanks to Hensel's
    # lifting lemma, this also works in modular arithmetic by doubling the
    # correct bits in each step.
    inverse = unsafe_mul(inverse, unsafe_sub(2, unsafe_mul(denominator_div, inverse))) # Inverse "mod 2**8".
    inverse = unsafe_mul(inverse, unsafe_sub(2, unsafe_mul(denominator_div, inverse))) # Inverse "mod 2**16".
    inverse = unsafe_mul(inverse, unsafe_sub(2, unsafe_mul(denominator_div, inverse))) # Inverse "mod 2**32".
    inverse = unsafe_mul(inverse, unsafe_sub(2, unsafe_mul(denominator_div, inverse))) # Inverse "mod 2**64".
    inverse = unsafe_mul(inverse, unsafe_sub(2, unsafe_mul(denominator_div, inverse))) # Inverse "mod 2**128".
    inverse = unsafe_mul(inverse, unsafe_sub(2, unsafe_mul(denominator_div, inverse))) # Inverse "mod 2**256".

    # Since the division is now exact, we can divide by multiplying
    # with the modular inverse of the denominator. This returns the
    # correct result modulo 2**256. Since the preconditions guarantee
    # that the result is less than 2**256, this is the final result.
    # We do not need to calculate the high bits of the result and
    # `prod1` is no longer necessary.
    result: uint256 = unsafe_mul(prod0, inverse)

    if (roundup and uint256_mulmod(x, y, denominator) != empty(uint256)):
        # Calculate "ceil((x * y) / denominator)". The following
        # line uses intentionally checked arithmetic to prevent
        # a theoretically possible overflow.
        result += 1

    return result


@external
@pure
def log_2(x: uint256, roundup: bool) -> uint256:
    """
    @dev Returns the log in base 2 of `x`, following the selected
         rounding direction.
    @notice Note that it returns 0 if given 0. The implementation is
            inspired by OpenZeppelin's implementation here:
            https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/Math.sol.
    @param x The 32-byte variable.
    @param roundup The Boolean variable that specifies whether
           to round up or not. The default `False` is round down.
    @return uint256 The 32-byte calculation result.
    """
    # For the special case `x == 0` we already return 0 here in order
    # not to iterate through the remaining code.
    if (x == empty(uint256)):
        return empty(uint256)

    return self._log_2(x, roundup)


@external
@pure
def log_10(x: uint256, roundup: bool) -> uint256:
    """
    @dev Returns the log in base 10 of `x`, following the selected
         rounding direction.
    @notice Note that it returns 0 if given 0. The implementation is
            inspired by OpenZeppelin's implementation here:
            https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/Math.sol.
    @param x The 32-byte variable.
    @param roundup The Boolean variable that specifies whether
           to round up or not. The default `False` is round down.
    @return uint256 The 32-byte calculation result.
    """
    value: uint256 = x
    result: uint256 = empty(uint256)

    # For the special case `x == 0` we already return 0 here in order
    # not to iterate through the remaining code.
    if (x == empty(uint256)):
        return empty(uint256)

    # The following lines cannot overflow because we have the well-known
    # decay behaviour of `log_10(max_value(uint256)) < max_value(uint256)`.
    if (x >= 10 ** 64):
        value = unsafe_div(x, 10 ** 64)
        result = 64
    if (value >= 10 ** 32):
        value = unsafe_div(value, 10 ** 32)
        result = unsafe_add(result, 32)
    if (value >= 10 ** 16):
        value = unsafe_div(value, 10 ** 16)
        result = unsafe_add(result, 16)
    if (value >= 10 ** 8):
        value = unsafe_div(value, 10 ** 8)
        result = unsafe_add(result, 8)
    if (value >= 10 ** 4):
        value = unsafe_div(value, 10 ** 4)
        result = unsafe_add(result, 4)
    if (value >= 10 ** 2):
        value = unsafe_div(value, 10 ** 2)
        result = unsafe_add(result, 2)
    if (value >= 10):
        result = unsafe_add(result, 1)

    if (roundup and (10 ** result < x)):
        result = unsafe_add(result, 1)

    return result


@external
@pure
def log_256(x: uint256, roundup: bool) -> uint256:
    """
    @dev Returns the log in base 256 of `x`, following the selected
         rounding direction.
    @notice Note that it returns 0 if given 0. Also, adding one to the
            rounded down result gives the number of pairs of hex symbols
            needed to represent `x` as a hex string. The implementation is
            inspired by OpenZeppelin's implementation here:
            https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/Math.sol.
    @param x The 32-byte variable.
    @param roundup The Boolean variable that specifies whether
           to round up or not. The default `False` is round down.
    @return uint256 The 32-byte calculation result.
    """
    value: uint256 = x
    result: uint256 = empty(uint256)

    # For the special case `x == 0` we already return 0 here in order
    # not to iterate through the remaining code.
    if (x == empty(uint256)):
        return empty(uint256)

    # The following lines cannot overflow because we have the well-known
    # decay behaviour of `log_256(max_value(uint256)) < max_value(uint256)`.
    if (shift(x, -128) != empty(uint256)):
        value = shift(x, -128)
        result = 16
    if (shift(value, -64) != empty(uint256)):
        value = shift(value, -64)
        result = unsafe_add(result, 8)
    if (shift(value, -32) != empty(uint256)):
        value = shift(value, -32)
        result = unsafe_add(result, 4)
    if (shift(value, -16) != empty(uint256)):
        value = shift(value, -16)
        result = unsafe_add(result, 2)
    if (shift(value, -8) != empty(uint256)):
        result = unsafe_add(result, 1)

    if (roundup and (shift(1, convert(shift(result, 3), int256)) < x)):
        result = unsafe_add(result, 1)

    return result


@external
@pure
def wad_ln(x: int256) -> int256:
    """
    @dev Calculates the natural logarithm of a signed integer with a
         precision of 1e18.
    @notice Note that it returns 0 if given 0. Furthermore, this function
            consumes about 1,400 to 1,650 gas units depending on the value
            of `x`. The implementation is inspired by Remco Bloemen's
            implementation under the MIT license here:
            https://xn--2-umb.com/22/exp-ln.
    @param x The 32-byte variable.
    @return int256 The 32-byte calculation result.
    """
    value: int256 = x

    assert x >= empty(int256), "Math: wad_ln undefined"

    # For the special case `x == 0` we already return 0 here in order
    # not to iterate through the remaining code.
    if (x == empty(int256)):
        return empty(int256)

    # We want to convert `x` from "10 ** 18" fixed point to "2 ** 96"
    # fixed point. We do this by multiplying by "2 ** 96 / 10 ** 18".
    # But since "ln(x * C) = ln(x) + ln(C)" holds, we can just do nothing
    # here and add "ln(2 ** 96 / 10 ** 18)" at the end.

    # Reduce the range of `x` to "(1, 2) * 2 ** 96".
    # Also remember that "ln(2 ** k * x) = k * ln(2) + ln(x)" holds.
    k: int256 = unsafe_sub(convert(self._log_2(convert(x, uint256), False), int256), 96)
    # Note that to circumvent Vyper's safecast feature for the potentially
    # negative expression `value <<= uint256(159 - k)`, we first convert the
    # expression `value <<= uint256(159 - k)` to `bytes32` and subsequently
    # to `uint256`. Remember that the EVM default behaviour is to use two's
    # complement representation to handle signed integers.
    value = convert(shift(convert(convert(shift(value, unsafe_sub(159, k)), bytes32), uint256), -159), int256)

    # Evaluate using a "(8, 8)"-term rational approximation. Since `p` is monic,
    # we will multiply by a scaling factor later.
    p: int256 = unsafe_add(shift(unsafe_mul(unsafe_add(value, 3273285459638523848632254066296), value), -96), 24828157081833163892658089445524)
    p = unsafe_add(shift(unsafe_mul(p, value), -96), 43456485725739037958740375743393)
    p = unsafe_sub(shift(unsafe_mul(p, value), -96), 11111509109440967052023855526967)
    p = unsafe_sub(shift(unsafe_mul(p, value), -96), 45023709667254063763336534515857)
    p = unsafe_sub(shift(unsafe_mul(p, value), -96), 14706773417378608786704636184526)
    p = unsafe_sub(unsafe_mul(p, value), shift(795164235651350426258249787498, 96))

    # We leave `p` in the "2 ** 192" base so that we do not have to scale it up
    # again for the division. Note that `q` is monic by convention.
    q: int256 = unsafe_add(shift(unsafe_mul(unsafe_add(value, 5573035233440673466300451813936), value), -96), 71694874799317883764090561454958)
    q = unsafe_add(shift(unsafe_mul(q, value), -96), 283447036172924575727196451306956)
    q = unsafe_add(shift(unsafe_mul(q, value), -96), 401686690394027663651624208769553)
    q = unsafe_add(shift(unsafe_mul(q, value), -96), 204048457590392012362485061816622)
    q = unsafe_add(shift(unsafe_mul(q, value), -96), 31853899698501571402653359427138)
    q = unsafe_add(shift(unsafe_mul(q, value), -96), 909429971244387300277376558375)

    # It is known that the polynomial `q` has no zeros in the domain.
    # No scaling is required, as `p` is already "2 ** 96" too large. Also,
    # `r` is in the range "(0, 0.125) * 2 ** 96" after the division.
    r: int256 = unsafe_div(p, q)

    # To finalise the calculation, we have to proceed with the following steps:
    #   - multiply by the scaling factor "s = 5.549...",
    #   - add "ln(2 ** 96 / 10 ** 18)",
    #   - add "k * ln(2)", and
    #   - multiply by "10 ** 18 / 2 ** 96 = 5 ** 18 >> 78".
    # In order to perform the most gas-efficient calculation, we carry out all
    # these steps in one expression.
    return shift(unsafe_add(unsafe_add(unsafe_mul(r, 1677202110996718588342820967067443963516166),\
                 unsafe_mul(k, 16597577552685614221487285958193947469193820559219878177908093499208371)),\
                 600920179829731861736702779321621459595472258049074101567377883020018308), -174)


@external
@pure
def wad_exp(x: int256) -> int256:
    """
    @dev Calculates the natural exponential function of a signed integer with
         a precision of 1e18.
    @notice Note that this function consumes about 810 gas units. The implementation
            is inspired by Remco Bloemen's implementation under the MIT license here:
            https://xn--2-umb.com/22/exp-ln.
    @param x The 32-byte variable.
    @return int256 The 32-byte calculation result.
    """
    value: int256 = x

    # If the result is `< 0.5`, we return zero. This happens when we have the following:
    # "x <= floor(log(0.5e18) * 1e18) ~ -42e18".
    if (x <= -42139678854452767551):
        return empty(int256)

    # When the result is "> (2 ** 255 - 1) / 1e18" we cannot represent it as a signed integer.
    # This happens when "x >= floor(log((2 ** 255 - 1) / 1e18) * 1e18) ~ 135".
    assert x < 135305999368893231589, "Math: wad_exp overflow"

    # `x` is now in the range "(-42, 136) * 1e18". Convert to "(-42, 136) * 2 ** 96" for higher
    # intermediate precision and a binary base. This base conversion is a multiplication with
    # "1e18 / 2 ** 96 = 5 ** 18 / 2 ** 78".
    value = unsafe_div(shift(x, 78), 5 ** 18)

    # Reduce the range of `x` to "(-½ ln 2, ½ ln 2) * 2 ** 96" by factoring out powers of two
    # so that "exp(x) = exp(x') * 2 ** k", where `k` is a signer integer. Solving this gives
    # "k = round(x / log(2))" and "x' = x - k * log(2)". Thus, `k` is in the range "[-61, 195]".
    k: int256 = shift(unsafe_add(unsafe_div(shift(value, 96), 54916777467707473351141471128), 2 ** 95), -96)
    value = unsafe_sub(value, unsafe_mul(k, 54916777467707473351141471128))

    # Evaluate using a "(6, 7)"-term rational approximation. Since `p` is monic,
    # we will multiply by a scaling factor later.
    y: int256 = unsafe_add(shift(unsafe_mul(unsafe_add(value, 1346386616545796478920950773328), value), -96), 57155421227552351082224309758442)
    p: int256 = unsafe_add(unsafe_mul(unsafe_add(shift(unsafe_mul(unsafe_sub(unsafe_add(y, value), 94201549194550492254356042504812), y), -96),\
                           28719021644029726153956944680412240), value), shift(4385272521454847904659076985693276, 96))

    # We leave `p` in the "2 ** 192" base so that we do not have to scale it up
    # again for the division.
    q: int256 = unsafe_add(shift(unsafe_mul(unsafe_sub(value, 2855989394907223263936484059900), value), -96), 50020603652535783019961831881945)
    q = unsafe_sub(shift(unsafe_mul(q, value), -96), 533845033583426703283633433725380)
    q = unsafe_add(shift(unsafe_mul(q, value), -96), 3604857256930695427073651918091429)
    q = unsafe_sub(shift(unsafe_mul(q, value), -96), 14423608567350463180887372962807573)
    q = unsafe_add(shift(unsafe_mul(q, value), -96), 26449188498355588339934803723976023)

    # The polynomial `q` has no zeros in the range because all its roots are complex.
    # No scaling is required, as `p` is already "2 ** 96" too large. Also,
    # `r` is in the range "(0.09, 0.25) * 2**96" after the division.
    r: int256 = unsafe_div(p, q)

    # To finalise the calculation, we have to multiply `r` by:
    #   - the scale factor "s = ~6.031367120",
    #   - the factor "2 ** k" from the range reduction, and
    #   - the factor "1e18 / 2 ** 96" for the base conversion.
    # We do this all at once, with an intermediate result in "2**213" base,
    # so that the final right shift always gives a positive value.

    # Note that to circumvent Vyper's safecast feature for the potentially
    # negative parameter value `r`, we first convert `r` to `bytes32` and
    # subsequently to `uint256`. Remember that the EVM default behaviour is
    # to use two's complement representation to handle signed integers.
    return convert(shift(unsafe_mul(convert(convert(r, bytes32), uint256), 3822833074963236453042738258902158003155416615667), -unsafe_sub(195, k)), int256)


@external
@pure
def cbrt(x: uint256, roundup: bool) -> uint256:
    """
    @dev Calculates the cube root of an unsigned integer.
    @notice Note that this function consumes about 1,600 to 1,800 gas units
            depending on the value of `x` and `roundup`. The implementation is
            inspired by Curve Finance's implementation under the MIT license here:
            https://github.com/curvefi/tricrypto-ng/blob/main/contracts/CurveCryptoMathOptimized3.vy.
    @param x The 32-byte variable from which the cube root is calculated.
    @param roundup The Boolean variable that specifies whether
           to round up or not. The default `False` is round down.
    @return The 32-byte cube root of `x`.
    """
    # For the special case `x == 0` we already return 0 here in order
    # not to iterate through the remaining code.
    if (x == empty(uint256)):
        return empty(uint256)

    y: uint256 = unsafe_div(self._wad_cbrt(x), 10 ** 12)

    if (roundup and (unsafe_mul(unsafe_mul(y, y), y) != x)):
        y = unsafe_add(y, 1)

    return y


@external
@pure
def wad_cbrt(x: uint256) -> uint256:
    """
    @dev Calculates the cube root of an unsigned integer with a precision
         of 1e18.
    @notice Note that this function consumes about 1,500 to 1,700 gas units
            depending on the value of `x`. The implementation is inspired
            by Curve Finance's implementation under the MIT license here:
            https://github.com/curvefi/tricrypto-ng/blob/main/contracts/CurveCryptoMathOptimized3.vy.
    @param x The 32-byte variable from which the cube root is calculated.
    @return The 32-byte cubic root of `x` with a precision of 1e18.
    """
    # For the special case `x == 0` we already return 0 here in order
    # not to iterate through the remaining code.
    if (x == empty(uint256)):
        return empty(uint256)

    return self._wad_cbrt(x)


@internal
@pure
def _log_2(x: uint256, roundup: bool) -> uint256:
    """
    @dev An `internal` helper function that returns the log in base 2
         of `x`, following the selected rounding direction.
    @notice Note that it returns 0 if given 0. The implementation is
            inspired by OpenZeppelin's implementation here:
            https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/Math.sol.
    @param x The 32-byte variable.
    @param roundup The Boolean variable that specifies whether
           to round up or not. The default `False` is round down.
    @return uint256 The 32-byte calculation result.
    """
    value: uint256 = x
    result: uint256 = empty(uint256)

    # The following lines cannot overflow because we have the well-known
    # decay behaviour of `log_2(max_value(uint256)) < max_value(uint256)`.
    if (shift(x, -128) != empty(uint256)):
        value = shift(x, -128)
        result = 128
    if (shift(value, -64) != empty(uint256)):
        value = shift(value, -64)
        result = unsafe_add(result, 64)
    if (shift(value, -32) != empty(uint256)):
        value = shift(value, -32)
        result = unsafe_add(result, 32)
    if (shift(value, -16) != empty(uint256)):
        value = shift(value, -16)
        result = unsafe_add(result, 16)
    if (shift(value, -8) != empty(uint256)):
        value = shift(value, -8)
        result = unsafe_add(result, 8)
    if (shift(value, -4) != empty(uint256)):
        value = shift(value, -4)
        result = unsafe_add(result, 4)
    if (shift(value, -2) != empty(uint256)):
        value = shift(value, -2)
        result = unsafe_add(result, 2)
    if (shift(value, -1) != empty(uint256)):
        result = unsafe_add(result, 1)

    if (roundup and (shift(1, convert(result, int256)) < x)):
        result = unsafe_add(result, 1)

    return result


@internal
@pure
def _wad_cbrt(x: uint256) -> uint256:
    """
    @dev An `internal` helper function that calculates the cube root of an
         unsigned integer with a precision of 1e18.
    @notice Note that this function consumes about 1,450 to 1,650 gas units
            depending on the value of `x`. The implementation is inspired
            by Curve Finance's implementation under the MIT license here:
            https://github.com/curvefi/tricrypto-ng/blob/main/contracts/CurveCryptoMathOptimized3.vy.
    @param x The 32-byte variable from which the cube root is calculated.
    @return The 32-byte cubic root of `x` with a precision of 1e18.
    """
    # Since this cube root is for numbers with base 1e18, we have to scale
    # the input by 1e36 to increase the precision. This leads to an overflow
    # for very large numbers. So we conditionally sacrifice precision.
    value: uint256 = empty(uint256)
    if (x >= unsafe_mul(unsafe_div(max_value(uint256), 10 ** 36), 10 ** 18)):
        value = x
    elif (x >= unsafe_div(max_value(uint256), 10 ** 36)):
        value = unsafe_mul(x, 10 ** 18)
    else:
        value = unsafe_mul(x, 10 ** 36)

    # Compute the binary logarithm of `value`.
    log2x: uint256 = self._log_2(value, False)

    # If we divide log2x by 3, the remainder is "log2x % 3". So if we simply
    # multiply "2 ** (log2x/3)" and discard the remainder to calculate our guess,
    # the Newton-Raphson method takes more iterations to converge to a solution
    # because it lacks this precision. A few more calculations now in order to
    # do fewer calculations later:
    #   - "pow = log2(x) // 3" (the operator `//` means integer division),
    #   - "remainder = log2(x) % 3",
    #   - "initial_guess = 2 ** pow * cbrt(2) ** remainder".
    # Now substituting "2 = 1.26 ≈ 1260 / 1000", we get:
    #   - "initial_guess = 2 ** pow * 1260 ** remainder // 1000 ** remainder".
    remainder: uint256 = log2x % 3
    y: uint256 = unsafe_div(unsafe_mul(pow_mod256(2, unsafe_div(log2x, 3)), pow_mod256(1260, remainder)), pow_mod256(1000, remainder))

    # Since we have chosen good initial values for the cube roots, 7 Newton-Raphson
    # iterations are just sufficient. 6 iterations would lead to non-convergences,
    # and 8 would be one iteration too many. Without initial values, the iteration
    # number can be up to 20 or more. The iterations are unrolled. This reduces the
    # gas cost, but requires more bytecode.
    y = unsafe_div(unsafe_add(unsafe_mul(2, y), unsafe_div(value, unsafe_mul(y, y))), 3)
    y = unsafe_div(unsafe_add(unsafe_mul(2, y), unsafe_div(value, unsafe_mul(y, y))), 3)
    y = unsafe_div(unsafe_add(unsafe_mul(2, y), unsafe_div(value, unsafe_mul(y, y))), 3)
    y = unsafe_div(unsafe_add(unsafe_mul(2, y), unsafe_div(value, unsafe_mul(y, y))), 3)
    y = unsafe_div(unsafe_add(unsafe_mul(2, y), unsafe_div(value, unsafe_mul(y, y))), 3)
    y = unsafe_div(unsafe_add(unsafe_mul(2, y), unsafe_div(value, unsafe_mul(y, y))), 3)
    y = unsafe_div(unsafe_add(unsafe_mul(2, y), unsafe_div(value, unsafe_mul(y, y))), 3)

    # Since we scaled up, we have to scale down accordingly.
    if (x >= unsafe_mul(unsafe_div(max_value(uint256), 10 ** 36), 10 ** 18)):
        return unsafe_mul(y, 10 ** 12)
    elif (x >= unsafe_div(max_value(uint256), 10 ** 36)):
        return unsafe_mul(y, 10 ** 6)
    else:
        return y
