export const mysqlLimits = {
  tinyint: {
    min: -128,
    max: 127
  },
  utinyint: {
    min: 0,
    max: 255
  },
  smallint: {
    min: -32768,
    max: 32767
  },
  usmallint: {
    min: 0,
    max: 65535
  },
  mediumint: {
    min: -8388608,
    max: 8388607
  },
  umediumint: {
    min: 0,
    max: 16777215
  },
  int: {
    min: -2147483648,
    max: 2147483647
  },
  uint: {
    min: 0,
    max: 4294967295
  },
  bigint: {
    min: -Math.pow(2, 63),
    max: Math.pow(2, 63) - 1
  },
  ubigint: {
    min: 0,
    max: Math.pow(2, 64) - 1
  }
}
