/*
 * Copyright (C) 2005 - 2019 TIBCO Software Inc. All rights reserved. Confidentiality & Proprietary.
 * Licensed pursuant to commercial TIBCO End User License Agreement.
 */

package groovy_column
import com.jaspersoft.commons.datarator.BaseColumnAdapter
import com.jaspersoft.commons.datarator.DataColumn
import com.jaspersoft.commons.datarator.RankingAggregateColumn
import com.jaspersoft.commons.datarator.WorkingDataSet
import com.jaspersoft.commons.dataset.expr.GenericExpressionFactory
import com.jaspersoft.commons.dimengine.AllValuesDimensionMember
import com.jaspersoft.commons.dimengine.DimensionMember
import com.jaspersoft.commons.dimengine.MeasureDimensionMember
import com.jaspersoft.commons.dimengine.TreeNode
import com.jaspersoft.commons.groovy.GroovyColumn
import com.jaspersoft.jasperserver.api.common.util.TimeZoneContextHolder
import com.jaspersoft.jasperserver.api.common.util.rd.DateRangeFactory
import net.sf.jasperreports.types.date.DateRange
import net.sf.jasperreports.types.date.DateRangeExpression
import org.joda.time.*

import java.math.MathContext
import java.math.RoundingMode
import java.sql.Time
import java.sql.Timestamp
import java.text.DateFormat
import java.text.DecimalFormat
import java.text.DecimalFormatSymbols
import java.text.SimpleDateFormat

class BaseGroovyColumn extends com.jaspersoft.commons.groovy.GroovyColumn {
    final MILLS_PER_SEC = 1000;
    final SECS_PER_MIN = 60G;
    final HOUR_PER_DAY = 24G;
    final DAYS_PER_WK = 7G;
    final DAYS_PER_MONTH = 30G;
    final MONTHS_PER_QUART = 3G;
    final MONTHS_PER_YR = 12G;

    DecimalFormat fm = new java.text.DecimalFormat("0.00", new DecimalFormatSymbols(Locale.ENGLISH));
    RankingAggregateColumn rankColumn;
    MathContext mc = new MathContext(3)
    GroovyColumn mainColumn

    def BaseGroovyColumn() {}

    // Generated Groovy for an expression has a "main" column which returns the result,
    // and optionally may have other columns producing intermediate results.
    // This constructor is called with just the type for the main column,
    // and with the type and main column for "subcolumns"
    // see GroovyGenerator.getColumn() for more info on order of instantiation.
    def BaseGroovyColumn(String typeName, GroovyColumn mainColumn = null) {
        // superclass needs columnFactory; we will have to set ours with the dataset
        super(typeName)
        // set things from the main column if we are a sub-column
        if (mainColumn) {
            setDataSet(mainColumn.ds)
            this.mainColumn = mainColumn
            this.groovyRunner = mainColumn.groovyRunner
        }
    }

    // called a couple times:
    // from constructor: ds is non-null when called for instant columns
    // from GroovyGenerator: will be non-null
    void setDataSet(WorkingDataSet ds) {
        super.setDataSet(ds)
    }

    // debug
    def p(Object[] args) { System.out.println("BaseGroovyColumn: " + args?.join(" ")) }

    // string functions
    boolean StartsWith(String str, String prefix) {str == null ? false : str.toLowerCase().startsWith(prefix.toLowerCase()) }

    boolean EndsWith(String str, String suffix) { str == null ? false : str.toLowerCase().endsWith(suffix.toLowerCase()) }

    boolean Contains(String str, String str2) { str == null ? false : str.toLowerCase().indexOf(str2.toLowerCase()) >= 0 }

    boolean equalsDate(Object dbValue, Object date) {
        return betweenDates(dbValue, date, date)
    }

    boolean afterDate(Object dbValue, Object date) {
        if (dbValue == null) return false
        Class dbValueClass = dbValue.getClass();
        def value = toReadableInstant(dbValue)
        def endDate = RelativeDate(date, false, dbValueClass)

        if (endDate == null) {
            return false;
        }

        value.isAfter(endDate)
    }

    boolean beforeDate(Object dbValue, Object date) {
        if (dbValue == null) return false
        Class dbValueClass = dbValue.getClass();
        def value = toReadableInstant(dbValue)
        def startDate = RelativeDate(date, true, dbValueClass)

        if (startDate == null) {
            return false;
        }

        value.isBefore(startDate)
    }

    boolean isOnOrAfterDate(Object dbValue, Object date) {
        if (dbValue == null) return false
        Class dbValueClass = dbValue.getClass();
        def value = toReadableInstant(dbValue)
        def startDate = RelativeDate(date, true, dbValueClass)

        if (startDate == null) {
            return false;
        }

        value.equals(startDate) || value.isAfter(startDate)
    }

    boolean isOnOrBeforeDate(Object dbValue, Object date) {
        if (dbValue == null) return false
        Class dbValueClass = dbValue.getClass();
        def value = toReadableInstant(dbValue)
        def endDate = RelativeDate(date, false, dbValueClass)

        if (endDate == null) {
            return false;
        }

        value.equals(endDate) || value.isBefore(endDate)
    }

    boolean betweenDates(Object dbValue, Object start, Object end) {
        if (dbValue == null) return (start == null && end == null)
        Class dbValueClass = dbValue.getClass();
        def value = toReadableInstant(dbValue)

        def startDate = RelativeDate(start, true, dbValueClass)
        def endDate = RelativeDate(end, false, dbValueClass)

        if (startDate != null && endDate != null && !(startDate.isBefore(endDate) || startDate.equals(endDate))) {
            return false;
        } else if (startDate == null && endDate == null) {
            return false;
        }

        return (startDate == null ? true : (value.equals(startDate) || value.isAfter(startDate))) &&
                (endDate == null ? true : (value.equals(endDate) || value.isBefore(endDate)))
    }

    ReadableInstant RelativeDate(Object obj, boolean start, Class valueClass) {
        if (obj == null) return null;
        if (obj instanceof ReadableInstant) return (ReadableInstant) obj

        def startDate
        def endDate

        def expr = obj instanceof DateRangeExpression ?
                obj.getExpression() : (obj instanceof DateRange ?
                String.valueOf(obj.getStart().getTime()) : (obj instanceof String ? obj : null));

        def cachedDates = expr ? cache?.get(expr) : null;
        if (cachedDates) {
            startDate = cachedDates[0]
            endDate = cachedDates[1]
        } else {
            Class<? extends Date> clazz = org.joda.time.DateTime.class.equals(valueClass) ? java.sql.Timestamp.class : java.util.Date.class

            // There we should use server timezone because each time and timestamp on that layer
            // represented in server zone
            def dateRange = (obj instanceof DateRange) ? (DateRange) obj : DateRangeFactory.getInstance(obj, TimeZone.getDefault(), clazz)

            startDate = new DateTime(dateRange.getStart())
            endDate = new DateTime(dateRange.getEnd())

            if (dateRange instanceof DateRangeExpression) {
                cache?.put(dateRange.getExpression(), [startDate, endDate]);
            } else {
                cache?.put(String.valueOf(dateRange.getStart().getTime()), [startDate, endDate]);
            }
        }

        return new DateTime(start ? startDate : endDate)
    }

    //added support of isAnyValue for all data types
//  boolean isAnyValue(String str) { str != null}
//  boolean isAnyValue(Long num) { num != null}
//  boolean isAnyValue(Double doub) { doub != null}
//  boolean isAnyValue(BigDecimal decimal) { decimal != null}
//  boolean isAnyValue(Boolean bool) { bool != null}
    boolean isAnyValue(Object... obj) { return true }

    def nothing(arg) { null }


    //  https://jira.tibco.com/browse/JS-31719
    //
    //  2017-04-05   thorick:  remove use of org.joda.time.DateMidnight
    //
    // cast to DateTime at the start of the day
    //
    DateTime Date(obj) {
        obj == null ? null : new LocalDate(obj).toDateTimeAtStartOfDay(DateTimeZone.forTimeZone(TimeZone.getDefault()))
    }

    // java version of "date" function used in audit domain
    def date(obj) { toDate(obj) }

    // java version of "time" function used in audit domain; expected to return timestamp
    def time(obj) { toTime(obj) }

    // java varsion of "str2int" used in domains
    def str2int(obj) { Integer.valueOf((String) obj) }

    // conversion function for java.util.Date
    def toDate(obj) {
        if (obj instanceof ReadableInstant) {
            return new java.util.Date(obj.millis)
        }
        return (java.util.Date) obj
    }

    // conversion function for java.sql.Time
    def toTime(obj) {
        if (obj instanceof java.sql.Timestamp) {
            return millisecondsToTime(obj.getTime())
        }
        if (obj instanceof ReadableInstant) {
            return millisecondsToTime(obj.millis)
        }
        if (obj instanceof ReadablePartial) {
            return millisecondsToTime(toDateTime(obj).millis)
        }
        return (java.sql.Time) obj
    }

    // java.sql.Time is a thin wrapper around java.util.Date that contains
    // the number of milliseconds since January 1, 1970, 00:00:00 GMT.
    // In the case when we convert Date or Timestamp to Time the date part is saved
    // and it causes an issue when we want to compare
    // two Time fields. So we need to reset date part.
    def millisecondsToTime(long milliseconds) {
        Timestamp ts = new Timestamp(milliseconds)
        // We reset the date part to start of the epoch so the nem Time field
        // will contains only milliseconds of hours, minutes, seconds and milliseconds.
        ts.setYear(70)
        ts.setMonth(0)
        ts.setDate(1)

        return new Time(ts.getTime())
    }

    //Bug 41136
    def second(Date date)
    {
        Calendar cal = Calendar.getInstance();
        cal.setTime(date);
        return cal.get(Calendar.SECOND);
    }
    def minute(Date date)
    {
        Calendar cal = Calendar.getInstance();
        cal.setTime(date);
        return cal.get(Calendar.MINUTE);
    }
    def hour(Date date) {
        Calendar cal = Calendar.getInstance();
        cal.setTime(date);
        return cal.get(Calendar.HOUR_OF_DAY);
    }

    def second(DateTime date)
    {
        return date.getSecondOfMinute();
    }
    def minute(DateTime date)
    {
        return date.getMinuteOfHour();
    }
    def hour(DateTime date) {
        return date.getHourOfDay();
    }

    // conversion function for java.sql.Timestamp
    def toTimestamp(obj) {
        if (obj == null || obj instanceof Timestamp) {
            return obj
        } else if (obj instanceof Time) {
            return new Timestamp(((Time) obj).getTime())
        } else if (obj instanceof Date) {
            return new Timestamp(obj.time)
        } else if (obj instanceof ReadablePartial) {
            return new Timestamp(toDateTime(obj).millis)
        } else if (obj instanceof ReadableInstant) {
            return new Timestamp(obj.millis)
        }
        throw new Exception("Timestamp function has invalid argument")
    }

    // these functions convert from Java date types to joda-time
    // Update: moved to GroovyColumn.java
    /*
    def toDateTime(timestamp) { timestamp == null ? null : new DateTime(timestamp) }
    */
    // support for calc fields (keep long & double separate)
    // update for bug 21368: for some reason we were falling back to Object[] version which used longs
    // don't know why that even worked, but must have something to do w/ method resolution
    // put in long and double versions of add and multiply; TBD, let's test big decimal

    def add(Long[] args) {
        BigInteger total = 0
        for (Long arg : args) {
            if (arg != null)
                total += arg
            else
                return null
        }
        return total
    }

    def add(double[] args) {
        double total = 0
        for (double arg : args) {
            total += arg
        }
        return total
    }

    def add(Object[] args) {
        BigDecimal total = 0
        for (BigDecimal arg : args) {
            if (arg != null)
                total += arg
            else
                return null;
        }
        return total
    }

    def subtract(arg1, arg2) {
        if (arg1 == null || arg2 == null) {
            return null
        }
        return arg1 - arg2;
    }

    def multiply(Long[] args) {
        BigInteger total = 1
        for (Long arg : args) {
            if (arg != null)
                total *= arg
            else
                return null
        }
        return total
    }

    def multiply(double[] args) {
        double total = 1
        for (double arg : args) {
            total *= arg
        }
        return total
    }

    def multiply(Object[] args) {
        BigDecimal total = 1
        for (BigDecimal arg : args) {
            if (arg != null)
                total *= (arg ?: 0)
            else
                return null
        }
        return total
    }

    // don't do separate versions of division because Groovy method resolution is flakey,
    // but we do need to handle BigDecimal separately
    def divide(arg1, arg2) {
        // if either arg is null, or if denominator is 0, return null
        def result
        if (arg1 == null || arg2 == null) {
            result = null
        } else if (arg2 == 0) {
            result = null
        } else if (arg1 instanceof BigDecimal) {
            result = arg1.divide(arg2, MathContext.DECIMAL64)
        } else {
            result = arg1 / arg2
        }
        result
    }

    def percentRatio(arg1, arg2) {
        def result
        if ((arg1 == null) ||  (arg2 == null)) {
            result = null
        }
        else {
            // call our versions which do null checking
            result = multiply(divide(arg1, arg2), 100)
        }
        result
    }

    def Round(BigDecimal arg1, precision = 0) {
        if (nullCheck(arg1)) {
            return null
        };
        return RoundBD(arg1, precision);
    }

    def Round(long arg1) {
        //p("RUN  round(long) "+arg1);
        if (nullCheck(arg1)) {
            return null
        };
        return arg1
    }

    def Round(double arg1, int precision = 0) {
        //p("RUN  Round(double, precision="+precision+") "+arg1);
        if (nullCheck(arg1)) {
            return null
        };
        BigDecimal bd = new BigDecimal(arg1);
        bd = RoundBD(bd, precision);
        return bd.doubleValue();
    }

    def RoundBD(BigDecimal arg1, int precision) {
        return arg1.setScale(precision, RoundingMode.HALF_UP);
    }

    def Absolute(double arg1) {
        if (Double.isNaN(arg1)) return Double.NaN;
        return Math.abs(arg1);
    }

    def Absolute(BigDecimal arg1) {
        return arg1?.abs();
    }

    def Absolute(long arg1) {
        return Math.abs(arg1);
    }


    //
    //  JasperSoft defines:  the index of the first char to be 0
    //  Java       defines:  the index of the first char to be 1
    //
    //  The String must be of length at least (in terms of input args)  start + length
    def Mid(String str, Long start, Long length = Integer.MAX_VALUE) {
        //p("input string='"+str+"'");
        if (str==null) return null;

        // all impossible requests return empty string
        if (start < 1)  return "";
        if (length < 1) return "";

        int strlen = str.length();
        if (start > strlen)  return "";

        // handle a string that is too short for the requested substring
        // return as much of it as is available, starting at the start index
        if (strlen < (start + length - 1)) {
            length = strlen - start + 1;
            if (length < 0)  length = 0;
        }

        String s = str.substring((int)(start-1), (int)(start + length - 1));
        //p("substring='"+s+"'\n");
        return s;
    }

    def Mid(String str, BigDecimal start, BigDecimal length = Integer.MAX_VALUE) {
        return Mid(str, start.longValue(), length.longValue())
    }

    // TODO calculate type correctly based on 2nd and 3rd args
    // TODO   2014-04-22 done for org.joda.time.DateTime only
    //
    def IF(boolean cond, Object whenTrue, Object whenFalse = null) {

        Object retVal;
        if (whenFalse != null) {
            retVal = cond ? whenTrue : whenFalse
        }
        else {
            retVal = cond ? whenTrue : null
        }
        if (retVal == null)  return retVal;

        //
        // http://bugzilla.jaspersoft.com/show_bug.cgi?id=37254
        //
        // joda DateTime happens to be a case that the Groovy runtime
        //       dynamic casting can't handle so we have to
        //
        if (retVal instanceof org.joda.time.DateTime) {
            retVal = toTimestamp(retVal);
        }
        return retVal;
    }

    //
    //  http://bugzilla.jaspersoft.com/show_bug.cgi?id=36953
    //
    //  version for DBMS that do not support boolean
    //
    def IF(Integer cond, Object whenTrue, Object whenFalse = null) {
        if (whenFalse != null) {
            cond != 0 ? whenTrue : whenFalse
        }
        else {
            cond != 0 ? whenTrue : null
        }
    }

    /**
     * There are really two types of case in SQL, so let's implement them both here
     * UPDATE: for sanity's sake, make them separate methods--Case and CaseWhen
     * Value (Case):           case <field> when <val1> then <ret1> when <val2> then <ret2> ...[ else <defaultRet>]
     * Conditional (CaseWhen): case when <cond1> then <ret1> when <cond2> then <ret2> ...[ else <defaultRet>]
     *
     * You can tell the difference by checking whether the first argument is boolean.
     *
     * Arguments for conditional case (like an extended "if"):
     * Arguments 0, 2, ... are conditions (except the last argument which is the "else" value)
     * Arguments 1, 3, ... and the last "else" argument are possible return values
     *
     * Arguments for value case:
     * Argument 0          is the field to test
     * Arguments 1, 3, ... are values of the test field
     * Arguments 2, 4, ... are the corresponding return values
     *
     * In any case (ahem), if there is an argument left over, it's the "else" argument, which is returned if
     * none of the tests succeed
     */

    def Case(Object... args) {
        def argList = args as List
        // for non conditional, we are testing values against first arg
        def testValue = argList.remove(0)
        while (true) {
            // we failed all the previous tests,
            // so return the remaining (else) value, or null
            if (argList.size() == 0) {
                return null
            } else if (argList.size() == 1) {
                return argList.remove(0)
            } else {
                // test against value
                def isTrue = (testValue == argList.remove(0))
                // grab the value to return whether or not we use it
                def trueReturn = argList.remove(0)
                // return the value or keep going
                if (isTrue) {
                    return trueReturn
                }
            }
        }
    }

    def CaseWhen(Object... args) {
        def argList = args as List
        while (true) {
            // we failed all the previous tests,
            // so return the remaining (else) value, or null
            if (argList.size() == 0) {
                return null
            } else if (argList.size() == 1) {
                return argList.remove(0)
            } else {
                // do the appropriate test
                def isTrue = argList.remove(0)
                // grab the value to return whether or not we use it
                def trueReturn = argList.remove(0)
                // return the value or keep going
                if (isTrue) {
                    return trueReturn
                }
            }
        }
    }

    // only difference between Case and CaseRange: we are testing for "less than or equal" instead of "equal"
    def CaseRange(Object... args) {
        def argList = args as List
        // for non conditional, we are testing values against first arg
        def testValue = argList.remove(0)
        while (true) {
            // we failed all the previous tests,
            // so return the remaining (else) value, or null
            if (argList.size() == 0) {
                return null
            } else if (argList.size() == 1) {
                return argList.remove(0)
            } else {
                // test against value
                def isTrue = (testValue <= argList.remove(0))
                // grab the value to return whether or not we use it
                def trueReturn = argList.remove(0)
                // return the value or keep going
                if (isTrue) {
                    return trueReturn
                }
            }
        }
    }

    def toBigDecimal(String num) {
        new BigDecimal(num).stripTrailingZeros()
    }

    /*
    def nullCheck(Object[] args) {
      args.any { it == null }
    }
    */

    // aggregates
    // please, let java do it!!
    /*
      def sum(Iterator i) {
          def sum = 0;
          i.each {
              if (it != null) { sum += it }
          }
          return sum;
      }
      */

    // version with data column and tree nodes
    def sum(DataColumn col) {
        sum(col, null)
    }

    def sum(DataColumn col, String level) {
        sum(iteratorForLevel(col, level))
    }

    def Sum(DataColumn col) {
        sum(col, null) }

    def Sum(DataColumn col, String level) {
        sum(col, level)
    }


    def average(DataColumn col) {
        average(col, null)
    }

    def average(DataColumn col, String level) {
        //p("groovy average for level="+(level == null ? "NULL" : level))
        average(iteratorForLevel(col, level))
    }

    def Average(DataColumn col)               { average(col, null)  }

    def Average(DataColumn col, String level) { average(col, level) }

    // some more implementations pushed down into GroovyColumn

    def Min(DataColumn col) {
        Min(col, null)
    }

    def Min(DataColumn col, String level) {
        Lowest(iteratorForLevel(col, level))
    }

    /*
    def Min(DataColumn col) {
      Lowest(col.iterator(and(rowNode, columnNode)))
    }
    */
    def min(DataColumn col) {
        min(col, null)
    }
    def min(DataColumn col, String level) {
        Lowest(iteratorForLevel(col, level))
    }

    //def Lowest(DataColumn col) {
    //  Lowest(col.iterator(and(rowNode, columnNode)))
    //}

    def Lowest(DataColumn col) {
        Lowest(col, null)
    }
    def Lowest(DataColumn col, String level) {
        Lowest(iteratorForLevel(col, level))
    }


    def Max(DataColumn col) {
        Max(col, null)
    }

    def Max(DataColumn col, String level) {
        Highest(iteratorForLevel(col, level))
    }

    def max(DataColumn col) {
        max(col, null)
    }

    def max(DataColumn col, String level) {
        Highest(iteratorForLevel(col, level))
    }

    def Highest(DataColumn col) {
        Highest(col, null)
    }

    def Highest(DataColumn col, String level) {
        Highest(iteratorForLevel(col, level))
    }

    def Count(DataColumn col) {
        Count(col.iterator(and(rowNode, columnNode)))
    }

    // default count implementation, which is used for constants or no-arg calls
    def Count(obj = null) {
        count(rowNode, columnNode)
    }

    def count(obj = null) {
        count(rowNode, columnNode)
    }


    def DistinctCount(DataColumn col) {
        DistinctCount(col.iterator(and(rowNode, columnNode)))
    }

    /*
     * this function would apply some error check before executing division
     * it would return NULL if invalid dividend or denominator passes in to this function
     */
    def divideForAverage(def dividend, def denominator) {
        if ((dividend == null) || (denominator == null)) return null;
        if (denominator == 0) return null;
        else return (dividend / denominator);
    }

    /**
     *  2014-01-06  thorick
     *
     *  This can be done faster in Java as compared to the Groovy impl below.
     *
     *  two (clunky) approaches:
     *
     *  1.  It will require us to extend our Java calculator interface
     *      to handle  pow(x, y), subtract(a, b), sqrt(x)  for the supported types.
     *      note that there is no BigDecimal.sqrt function
     *      (one would probably cast to double to do the calc and convert the result back to BigDecimal)
     *
     *  2.  Convert all inputs to double, do the calculation in double and
     *      reconvert the result back to the input type,
     *      one has to be careful about losing precision during the conversion from double
     *      to BigDecimal.
     *
     */
    def StdDevP(DataColumn col) {
        StandardDeviation(col, null, false)
    }

    def StdDevP(DataColumn col, String level) {
        StandardDeviation(col, level, false)
    }

    def StdDevS(DataColumn col) {
        StandardDeviation(col, null, true)
    }

    def StdDevS(DataColumn col, String level) {
        StandardDeviation(col, level, true)
    }

    @Override
    def Object StdDevP_java(Iterator<Object> itr) {
        return StandardDeviation(itr, average(itr), false)
    }
    @Override
    def Object StdDevS_java(Iterator<Object> itr) {
        return StandardDeviation(itr, average(itr), true)
    }

    def StandardDeviation(DataColumn col, String level, boolean sample) {
        StandardDeviation(iteratorForLevel(col, level),  average(col, level), sample);
    }

    def StandardDeviation(def i, def mean, boolean sample) {
        //def start =System.currentTimeMillis();

        def sum_variance = 0d;
        def count = 0i;
        //p("avg: $mean");
        i.each {
            if (it != null) {
                def diffsquared = Math.pow(it - mean, 2);
                sum_variance += diffsquared;

                count++;
                //p("value = $it, diff = ${it - mean}, diffsquared = $diffsquared, sum_variance = $sum_variance");
            }
        }
        //def end = System.currentTimeMillis();
        //def elapsed = end - start;
        //p("StandardDeviation total time="+elapsed);
        def divisor = count;
        if (sample)  divisor = divisor - 1;

        if (divisor <= 0) return null;

        // the sample standard deviation uses  count - 1
        // this is what we will use
        //p("count: $count, divisor: $divisor, sum_variance: $sum_variance, variance: ${sum_variance / count}, stddev: ${Math.sqrt(sum_variance / divisor)}");
        return divisor ? Math.sqrt(sum_variance / divisor) : 0;
    }


    def WeightedAverage(DataColumn targetDataColumn, DataColumn weightingDataColumn) {
        WeightedAverage(targetDataColumn, weightingDataColumn, null)
    }

    def WeightedAverage(DataColumn targetDataColumn, DataColumn weightingDataColumn, String level) {
        //p("called WeightedAverage with args='"+targetDataColumn+"', '"+weightingDataColumn+
        //         "', level="+(level == null ? "CURRENT" : level)+"\n");
        // get the row iterator for the targetMeasure for use to enumerate the rows
        // then compute and add up the components for the weighted average
        def sumY = 0.0d;
        def sumXY = 0.0d;
        //def sumX = 0.0d;   // debug only

        def i = rowIteratorForLevel(targetDataColumn, level);
        def counter = 0;
        i.each {
            //p("\ncounter="+(counter++));
            def y = weightingDataColumn.get(it);
            def x = targetDataColumn.get(it);

            //p("y="+(y == null ? "NULL" : y)+", x="+(x == null ? "NULL" : x)+"\n");
            if (x != null & y != null) {
                sumY += y;
                sumXY += x * y;
            }
            //sumX += x;
            //p("y="+y+", x="+x+", sumX="+sumX+", sumY="+sumY+", x*y="+(x*y)+", sumXY="+sumXY+"\n");
        }
        if (sumY == 0 || sumXY == 0)  return 0;
        def weightedAverage = sumXY / sumY;
        //p("weightedAverage="+weightedAverage+"\n");
        return weightedAverage;
    }

    def LookupValue(DataColumn dataColumn) {
        lookupValue(dataColumn);
    }

    def lookupValue(DataColumn dataColumn) {
        p("Hello world!");
    }

    def LookupValue(DataColumn dataColumn, DataColumn discriminatorCol) {
        lookupValue(dataColumn, discriminatorCol);
    }

    def lookupValue(DataColumn dataColumn, DataColumn discriminatorCol) {
        def orgBitSet = and(rowNode, columnNode);
        // p("rowNode = " + rowNode)
        // p("columnNode = " + columnNode)
        def key;
        def isRowSetFiltered = (rowNode != null) && ! rowNode.set.isAll();
        // column node can be node if it is table without details
        def isColumnSetFiltered = (columnNode != null) && ! columnNode.set.isAll();
        def curRowNode = rowNode;
        def curColumnNode = columnNode;
        DimensionMember rowMember = null;
        def rowLevel = 0;
        DimensionMember colMember = null;
        def colLevel = 0;

        if (isRowSetFiltered) {
            rowLevel = rowNode.level;
            rowMember = rowNode.getMember();
            // if it is MemberDimensionMember, go up one more level
            if (rowMember instanceof MeasureDimensionMember) {
                curRowNode = rowNode.getParent();
                rowMember = curRowNode.getMember();
                rowLevel--;
            }
            else {
                // if parents are measure dimension member, deduct level index
                def tmpNode = rowNode;
                while (tmpNode.getParent() != null && tmpNode.getParent().getMember() != null) {
                    if (tmpNode.getParent().getMember() instanceof MeasureDimensionMember) rowLevel--;
                    tmpNode = tmpNode.getParent();
                }
            }
        }
        if (isColumnSetFiltered) {
            colLevel = columnNode.level;
            colMember = columnNode.getMember();
            // if it is MemberDimensionMember, go up one more level
            if (colMember instanceof MeasureDimensionMember) {
                curColumnNode = columnNode.getParent();
                colMember = curColumnNode.getMember();
                colLevel--;
            }
            else {
                def tmpNode = columnNode;
                // if parents are measure dimension member, deduct level index
                while (tmpNode.getParent() != null && tmpNode.getParent().getMember() != null) {
                    if (tmpNode.getParent().getMember() instanceof MeasureDimensionMember) colLevel--;
                    tmpNode = tmpNode.getParent();
                }
            }
        }
        // if both row node bit set and column node bit set are not filtered, look up the grand total (0|0)
        if ((!isRowSetFiltered) && (!isColumnSetFiltered)) {
            key = "0|0";
        } else {
            // find the current row level
            if (isRowSetFiltered) {
                while ((curRowNode != null) && (rowMember.containsAll() || (rowMember instanceof AllValuesDimensionMember))) {
                    rowLevel--;
                    curRowNode = curRowNode.getParent();
                    if (curRowNode != null) {
                        rowMember = curRowNode.getMember();
                    }
                }
            }
            // find the current column level
            if (isColumnSetFiltered) {
                while ((curColumnNode != null) && (colMember.containsAll() || (colMember instanceof AllValuesDimensionMember))) {
                    colLevel--;
                    curColumnNode = curColumnNode.getParent();
                    if (curColumnNode != null) {
                        colMember = curColumnNode.getMember();
                    }
                }
            }
            key = rowLevel + "|" + colLevel;
        }
        // p("KEY = " + key);
        def disBitSet = discriminatorCol.getRowSet(key);
        // p("disBitSet = " + disBitSet);
        def rowIndex = -1;
        if (disBitSet == null) rowIndex = orgBitSet.nextSetBit(0);
        if (rowIndex < 0 && orgBitSet == null) rowIndex = disBitSet.nextSetBit(0);
        if (rowIndex < 0) {
            def newSet = orgBitSet.and(disBitSet);
            rowIndex = newSet.nextSetBit(0);
        }
        // p("ROW INDEX = " + rowIndex);
//
        if (rowIndex >= 0) {
            // p("ROW INDEX = " + rowIndex + " KEY = " + key + " value = " + dataColumn.get(rowIndex));
            return dataColumn.get(rowIndex);
        } else {
            // p("ROW INDEX = " + rowIndex + " KEY = " + key);
            return null;
        }
    }



    // get the result of and-ing the sets for two tree nodes (null if both sets are null)
    def andAggregate(TreeNode rnode, TreeNode cnode = null) {

        //p("calling rownode agg")
        def rset = rnode?.getColumnSet(columnKey)
        //psets(rnode, "rows agg")
        //p("calling colnode")
        def cset = cnode?.getColumnSet(columnKey)
        //psets(cnode, "cols")
        if (rset == null) {
            return cset
        } else {
            return (cset == null) ? rset : rset.and(cnode.getColumnSet(columnKey))
        }

    }

    // tree node ops



    // get the result of and-ing the sets for two tree nodes (null if both sets are null)
    def and(TreeNode rnode, TreeNode cnode = null) {

        //p("calling rownode general")
            def rset = rnode?.set
        //psets(rnode, "rows")
        //p("calling colnode general")
            def cset = cnode?.set
	//psets(cnode, "cols")
          if (rset == null) {
                return cset
            } else {
                return (cset == null) ? rset : rset.and(cnode.set)
            }

    }

    def and1(TreeNode rnode, TreeNode cnode = null) {

        def rset = rnode?.getColumnSet(columnKey)
//	psets(rnode, "rows")
        def cset = cnode?.getColumnSet(columnKey)
//	psets(cnode, "cols")
        if (rset == null) {
            return cset
        } else {
            return (cset == null) ? rset : rset.and(cnode.getColumnSet(columnKey))
        }

    }

    // common code to calculate percent
    def percentResult(datacol, topSet, bottomSet) {
        //p("percentResult.")
        def bottomSum = sum(datacol.iterator(bottomSet))
        def topSum = sum(datacol.iterator(topSet))
        //p("top   : " + topSet?.cardinality() + "/" + topSum)
        //p("bottom: " + bottomSet?.cardinality() + "/" + bottomSum)
        bottomSum == 0 ? 100 : (topSum != null ? topSum * 100d / bottomSum : null)

    }

    // you can find root from row node because it will always be there, but root of row & col is the same
    def percent(DataColumn datacol) {
        //p("percent.")
        def myset = and(rowNode, columnNode)
        // get root node which provides overall dataset filter
        def rootset = rowNode ? rowNode.root.set : columnNode.root.set
        percentResult(datacol, myset, rootset)
    }

    /////////////////////////////////////////////////////////
    // 2014-01-23  thorick
    //
    //  pre-v5.6  percentOf functions
    //  leave them as is for exact backwards compatibility !
    //
    def percentOfColumnParent(DataColumn datacol) {
        //p("percentOfColumnParent")
        def myset = and(rowNode, columnNode)
        def parentset = and(rowNode, columnNode?.logicalParent)
        def result = percentResult(datacol, myset, parentset)
        // p("%CGP for " + rowNode?.path + " and " + columnNode?.path + " = " + result)
        return result
    }

    def percentOfRowParent(DataColumn datacol) {
        //p("percentOfRowParent")
        def myset = and(rowNode, columnNode)
        def parentset = and(rowNode?.logicalParent, columnNode)
        percentResult(datacol, myset, parentset)
    }

    def percentOfRow(DataColumn datacol) {
        //p("percentOfRow")
        def myset = and(rowNode, columnNode)
        def parentset = and(rowNode, rowNode?.root)
        percentResult(datacol, myset, parentset)
    }

    def percentOfColumn(DataColumn datacol) {
        //p("percentOfColumn")
        def myset = and(rowNode, columnNode)
        def parentset = and(columnNode, rowNode?.root)
        percentResult(datacol, myset, parentset)
    }
    //
    //  END of pre-v5.6 percentOf functions
    //////////////////////////////////////////////////////////


    ////////////////////
    //   percentOf  functions recast for JRS version 5.6
    //
    //   essentially the same code as pre-5.6 but using repackaged
    //   obtain bitSet methods that will also be used by new 5.6 features
    //


    def PercentOf(DataColumn datacol, String level = "TOTAL") {
        // thorick   say wha ???
        //def mySet = bitSetForLevel(level);
        //p("PercentOf with level ="+(level == null ? "NULL" : level));

        def mySet = bitSetForLevel("CURRENT");
        //p("   got bitSetForLevel CURRENT");
        //p("   next get bitSet 'completeSet' for Level="+level);

        def completeSet = bitSetForLevel(level);
        //p("   got bitSetForCompleteSet for level="+level+",  now call percentResult()");
        percentResult(datacol, mySet, completeSet);
    }

    def iteratorForLevel(DataColumn datacol) {
        iteratorForLevel(datacol, "CURRENT");
    }

    def iteratorForLevel(DataColumn datacol, String level){
        // Check if needed to iterate through aggregate column
        if ((rowNode == null? true: rowNode.isTimeBalanceOperation(columnKey))
                && (columnNode == null? true: columnNode.isTimeBalanceOperation(columnKey))) {
            def bitSet = bitSetForAggregateLevel(level);
            //p("aggregate bitset")
            //p(bitSet)
            if (!bitSet?.isEmpty()) {
                // JRS-12922, second part of the fix so make sure in case we have nested columns.
                ((BaseColumnAdapter) this).aggregateColumn.iterator(bitSet)
            } else if(rowNode.isSummaryNode() || columnNode.isSummaryNode()) {
                // If we have an empty bitSet and row or column node is summary node - return bitSet from the datacol.
                // Empty bitSet means that TimeBalance was not calculated during Crosstab's Tree traverse, this can
                // happen if row or column tree leaf is not expanded, so we have only Totals and Grand Totals
                datacol.iterator(bitSetForLevel(level))
            }
        } else {
            def bitSet = bitSetForLevel(level);
            //p("general bitset")
            //p(bitSet)
            datacol.iterator(bitSet);
        }
    }

    def rowIteratorForLevel(DataColumn datacol, String level) {
        def bitSet = bitSetForLevel(level);
        datacol.rowIterator(bitSet);
    }


    def bitTimeSetForLevel(String level = "CURRENT") {
        def bitSet = and(rowNode, columnNode);
        return bitSet;
    }


    def bitSetForAggregateLevel(String level = "CURRENT") {
        level = level == null ? "CURRENT" : level;
        def bitSet = null;
        //p("bitSetForLevel Level='"+level+"'");
        //p("rowNode is "+(rowNode == null ? "" : "NOT")+" null");
        //p("colNode is "+(columnNode == null ? "" : "NOT")+" null");
        switch (level.toUpperCase()) {
            case "CURRENT":
                //p(rowNode.toString() + " "+columnNode.toString());

                bitSet = andAggregate(rowNode, columnNode);
                //p(bitSet.toString());
                break;
            case "ROWGROUP":
                bitSet = andAggregate(rowNode?.logicalParent, columnNode);
                break;
            case "ROWTOTAL":
                bitSet = andAggregate(rowNode?.root, columnNode);
                break;
            case "COLUMNGROUP":
                bitSet = andAggregate(rowNode, columnNode?.logicalParent);
                break;
            case "COLUMNTOTAL":
                bitSet = andAggregate(rowNode, columnNode?.root);
                break;
            case "TOTAL":
                //p(" at BaseGroovyColumn.groovy   bitSetForLevel  with level="+level+", columnNode class "+columnNode.getClass().getName());
                //p("     skip columnNode.root check");
                //if (columnNode != null)  p("    columnNode.root is "+(columnNode.root == null ? "" : "NOT ") + "NULL");

                //p("      rowNode is "+(rowNode == null ? "" : "NOT ")+" NULL.");
                //if (rowNode != null) {
                //     p("        rowNode.getRoot() is "+(rowNode.getRoot() == null ?  "" : "NOT ")+"NULL");
                //}
                bitSet = rowNode ? rowNode.root.set : columnNode.root.set;
                break;
            default:
                throw new RuntimeException("unhandled LEVEL type='"+level+"'");

        }
        return bitSet;
    }


    def bitSetForLevel(String level = "CURRENT") {
        level = level == null ? "CURRENT" : level;
        def bitSet = null;
        //p("bitSetForLevel Level='"+level+"'");
    //p("rowNode is "+(rowNode == null ? "" : "NOT")+" null");
    //p("colNode is "+(columnNode == null ? "" : "NOT")+" null");
        switch (level.toUpperCase()) {
          case "CURRENT":
            //p(rowNode.toString() + " "+columnNode.toString());bitSet = and(rowNode, columnNode);//p(bitSet.toString());
              bitSet = and(rowNode, columnNode);
            break;
          case "ROWGROUP":
            bitSet = and(rowNode?.logicalParent, columnNode);
            break;
          case "ROWTOTAL":
            bitSet = and(rowNode?.root, columnNode);
            break;
          case "COLUMNGROUP":
            bitSet = and(rowNode, columnNode?.logicalParent);
            break;
          case "COLUMNTOTAL":
            bitSet = and(rowNode, columnNode?.root);
            break;
          case "TOTAL":
            //p(" at BaseGroovyColumn.groovy   bitSetForLevel  with level="+level+", columnNode class "+columnNode.getClass().getName());
            //p("     skip columnNode.root check");
            //if (columnNode != null)  p("    columnNode.root is "+(columnNode.root == null ? "" : "NOT ") + "NULL");

                //p("      rowNode is "+(rowNode == null ? "" : "NOT ")+" NULL.");
                //if (rowNode != null) {
                //     p("        rowNode.getRoot() is "+(rowNode.getRoot() == null ?  "" : "NOT ")+"NULL");
                //}
                bitSet = rowNode ? rowNode.root.set : columnNode.root.set;
                break;
            default:
                throw new RuntimeException("unhandled LEVEL type='"+level+"'");

        }
        return bitSet;
    }





    int Rank(DataColumn datacol) {
        if (rankColumn == null) {
            // if we are columnizing the rank function, ds is a Reference which we have to dereference 8-P
            def wds = (ds instanceof Reference ? ds.get() : ds)
            rankColumn = new RankingAggregateColumn(datacol, wds )
        }
        if (rowNode || columnNode) {
            def myset = and(rowNode, columnNode)
            return rankColumn.getValue(myset)
        } else {
            return rankColumn.getValue(row)
        }
    }

    def Mode(DataColumn datacol) {
        Mode(datacol, null)
    }

    def Mode(DataColumn datacol, String level) {
        Mode_java(iteratorForLevel(datacol, level))
    }

    def Median(DataColumn datacol) {
        Median(datacol, null)
    }

    def Median(DataColumn datacol, String level) {
        Median_java(iteratorForLevel(datacol, level))
    }

    //  'Range' is the general purpose Range which is supposed to work
    //          on both Numeric and Date-Time values
    def Range(DataColumn datacol) {
        Range(datacol, null)
    }

    def Range(DataColumn datacol, String level) {
        Range_java(iteratorForLevel(datacol, level))
    }

    def CountAll() {
        def theSet = bitSetForLevel()
        theSet ? theSet.cardinality() : ds.rowCount
    }

    def CountAll(DataColumn datacol) {
        CountAll(datacol, null)
    }

    def CountAll(DataColumn datacol, String level) {
        CountAll_java(iteratorForLevel(datacol, level))
    }

    def CountIf(DataColumn datacol, String level = null) {
        def iter = iteratorForLevel(datacol, level)
        int c
        while (iter.hasNext()) {
            def v = iter.next()
            if(v) { c++ }
        }
        return c
    }

    def CountDistinct(DataColumn datacol) {
        CountDistinct(datacol, null)
    }

    def CountDistinct(DataColumn datacol, String level) {
        CountDistinct_java(iteratorForLevel(datacol, level))
    }

    /*

    agg function should have this def:
    def agg(BitSet set, DataColumn col1 ...)
    Or you could just do a closure taking a TreeNode:
    { TreeNode n -> col

    new idea for rank

    def rankNodeSet(Set<TreeNode> nodeSet, Closure nodeEval) {
        List<TreeNode> byValue = new ArrayList(nodeSet)
        byValue.sort { n1, n2 -> nodeEval(n1.set) <=> nodeEval(n2.set) }
        def map = [:]
        byValue.each { map[it] = map.size() + 1) }
        return map
    }
    */

    /**
     * ==================================
     * These are date diff helper methods
     * UPDATE: moved to GroovyColumn.java
     * ==================================
     */
    //note: not using Seconds.secondsBetween(arg1, arg2) due to buffer overflow when date diff > 2^(31) - 1 (max int)
    /*
    def getMilliSeconds(arg1, arg2){
      return (arg1.getMillis() - arg2.getMillis());
    }

    def getSeconds(arg1, arg2){
      long secs = getMilliSeconds(arg1, arg2);
      return (secs / MILLS_PER_SEC).toLong();
    }

    def getMinutes(arg1, arg2){
      def seconds = getSeconds(arg1, arg2);
      return (seconds / SECS_PER_MIN);
    }

    def getHours(arg1, arg2){
      def mins = getMinutes(arg1, arg2);
      return (mins / SECS_PER_MIN);
    }

    def getDays(arg1, arg2){
      def hours = getHours(arg1, arg2);
      return (hours / HOUR_PER_DAY);
    }

    def getWeeks(arg1, arg2){
      def days = getDays(arg1, arg2);
      return (days / DAYS_PER_WK);
    }

    def getMonths(arg1, arg2){
      def days = getDays(arg1, arg2);
      return (days/DAYS_PER_MONTH);
    }

  */
    /**
     * ====================================
     * These are the main date diff methods
     * ====================================
     */
/*
  def dateDiffInSeconds(arg1, arg2){
    if (nullCheck(arg1, arg2)){
      return null
    };
    def seconds = getSeconds(arg1, arg2)
    return seconds
  }

  def dateDiffInMinutes(arg1, arg2){
    if (nullCheck(arg1, arg2)){
      return null
    };
    def minutes = getMinutes(arg1, arg2);
    def formattedMins = fm.format(minutes);
    return new BigDecimal(formattedMins);
  }

  def dateDiffInHours(arg1, arg2){
    if (nullCheck(arg1, arg2)){
      return null
    };
    def hours = getHours(arg1, arg2);
    def formattedMins = fm.format(hours);
    return new BigDecimal(formattedMins);
  }

  def dateDiffInDays(arg1, arg2){
    if (nullCheck(arg1, arg2)){
      return null
    };
    def days = getDays(arg1, arg2);
    def formattedMins = fm.format(days);
    return new BigDecimal(formattedMins);
  }

  def dateDiffInWeeks(arg1, arg2){
    if (nullCheck(arg1, arg2)){
      return null
    };
    def weeks = getWeeks(arg1, arg2);
    def formattedMins = fm.format(weeks);
    return new BigDecimal(formattedMins);
  }

  def dateDiffInMonths(arg1, arg2){
    if (nullCheck(arg1, arg2)){
      return null
    };
    def months = getMonths(arg1, arg2);
    def formattedMins = fm.format(months);
    return new BigDecimal(formattedMins);
  }

  def dateDiffInQuarters(arg1, arg2){
    if (nullCheck(arg1, arg2)){
      return null
    };
    def months = getMonths(arg1, arg2);
    def formattedMins = fm.format((months/MONTHS_PER_QUART));
    return new BigDecimal(formattedMins);
  }
*/

    BigDecimal dateDiffInYears(ReadableDateTime arg1, ReadableDateTime arg2) {
        if (nullCheck(arg1, arg2)){
            return null
        };
        def months = getMonths(arg1, arg2)
        def years = dateDiffToBigDecimal(months / MONTHS_PER_YR)
        def result = super.dateDiffInYears(arg1, arg2)
        return result
    }

    BigDecimal dateDiffToBigDecimal(double d) {
        return new BigDecimal(d).setScale(getDateDiffPrecision(), RoundingMode.HALF_UP);
    }


    BigDecimal RangeMinutes(DataColumn datacol) {
        RangeMinutes_java(iteratorForLevel(datacol));
    }

    BigDecimal RangeHours(DataColumn datacol) {
        RangeHours_java(iteratorForLevel(datacol));
    }

    BigDecimal RangeDays(DataColumn datacol) {
        RangeDays_java(iteratorForLevel(datacol));
    }

    BigDecimal RangeWeeks(DataColumn datacol) {
        RangeWeeks_java(iteratorForLevel(datacol));
    }

    BigDecimal RangeMonths(DataColumn datacol) {
        RangeMonths_java(iteratorForLevel(datacol));
    }

    BigDecimal RangeQuarters(DataColumn datacol) {
        RangeQuarters_java(iteratorForLevel(datacol));
    }

    BigDecimal RangeSemis(DataColumn datacol) {
        RangeSemis_java(iteratorForLevel(datacol));
    }

    BigDecimal RangeYears(DataColumn datacol) {
        RangeYears_java(iteratorForLevel(datacol));
    }

    // get a Joda DateTime and adjust timezone to the current user's timezone (from TimeZoneContextHolder)

    def toJodaDateTime(Object o) {
        def dt = o
        if (! (o instanceof DateTime)) {
            dt = new DateTime(o)
        }
        TimeZone tz = TimeZoneContextHolder.getTimeZone()
        dt.withZone(DateTimeZone.forTimeZone(tz))
    }

    String MonthName(Object date) {
        if (date == null)  return null;
        def jodaDate = toJodaDateTime(date)
        jodaDate.toString("MMMM", ds.localeOrDefault)
    }

    String DayName(Object date) {
        if (date == null) return null;
        def jodaDate = toJodaDateTime(date)
        jodaDate.toString("EEEE", ds.localeOrDefault)
    }

    java.lang.Integer Year(Object date) {
        if (date == null) return null;
        toJodaDateTime(date).year
    }

    java.lang.Integer MonthNumber(Object date) {
        if (date == null) return null;
        toJodaDateTime(date).monthOfYear
    }

    java.lang.Integer DayNumber(Object date) {
        if (date == null) return null;
        if (date == null) return null;
        toJodaDateTime(date).dayOfMonth
    }

    def Today(Integer dayOffSet) {
        LocalDate.now()
                .plusDays((dayOffSet == null ? 0 : dayOffSet))
                .toDate()
    }

    def getNow() {
        MutableDateTime time = MutableDateTime.now();
        return time.toDate();
    }

    //custom contains method
    def customContains(arg1, list) {
        if (nullCheck(list)) {
            return false;
        };
        if (list.contains(arg1)) {
            return true;
        }
        // check if string values are in the list even if the elements types are different
        return checkContains(list, arg1);
    }

    def customDoublesContains(arg1, list, truncatedList) {
        return customDoublesContains(arg1, list)
    }

    def customDoublesContains(arg1, list) {
        if (nullCheck(list)) {
            return false
        }
        if (list.contains(arg1)) return true
        // we almost need to check if numbers are close enough
        return checkDoubleContains(list, arg1)
    }

    // truncate last 5 bits for double precision issue (bug # 33504)
    def truncatingEpsilon(double arg) {
        return Double.longBitsToDouble(Double.doubleToLongBits(arg) & -32L);
    }

    def customDecimalsContains(BigDecimal arg1, list) {
        if (nullCheck(list)) {
            return false;
        };
        def value = arg1 != null ? arg1.stripTrailingZeros() : arg1;
        if (list.contains(value)) return true;
        // JRS-12878 return false if value is null
        if (value == null) return false;
        double t = (double) value;
        return list.contains(new BigDecimal(t + ""));
    }

    // implement testProfileAttribute() in groovy
    // we can assume that user will be the same for the brief life of this object
    def attrMap = [:]

    def getAttrValueList(testAttrName) {
        def list = attrMap.get(testAttrName)
        if (!list) {
            def attrVal = attributesService.getAttribute(testAttrName, null)?.attrValue
            list = attrVal?.split(",").collect {it.trim()}
            attrMap.put(testAttrName, list)
        }
        list
    }

    def testProfileAttribute(value, testAttrName) {
        def list = getAttrValueList(testAttrName)
        def result = list && list.contains(value)
        result
    }

    def Attribute(attrName, category = null) {
        return attributesService.getAttribute(attrName, category, true)?.attrValue
    }

    def Integer(value) {
        if (value instanceof Integer) {
            return value;
        } else if (value instanceof String) {
            return new BigInteger(value)
        } else {
            throw new Exception("Integer function has invalid argument")
        }
    }

    def Decimal(obj) {
        if (obj instanceof BigDecimal) {
            return obj;
        } else if (obj instanceof String) {
            return toBigDecimal(obj);
        } else {
            throw new Exception("Decimal function has invalid argument")
        }
    }

    def Time(obj) {
        if (obj instanceof Time) {
            return obj
        } else if (obj instanceof String) {
            obj = obj.replace("%3A", ":");

            // check whether the time string is in hh:mm:ss.SSS format
            // if there is contains ".", millisecond is included
            boolean haveMillisecondField = obj.indexOf(".") > 0;
            DateFormat formatter;

            if (haveMillisecondField) {
                formatter = new SimpleDateFormat(GenericExpressionFactory.STANDARD_TIMEWITHMILLISEC_FORMAT);
            } else {
                formatter = new SimpleDateFormat(GenericExpressionFactory.STANDARD_TIME_FORMAT);
            }

            return new Time(formatter.parse(obj).getTime());
        } else if (obj instanceof ReadableInstant) {
            return toTime(obj)
        } else if (obj instanceof ReadablePartial) {
            return toTime(obj)
        } else {
            throw new Exception("Time function has invalid argument")
        }
    }

    def Timestamp(obj) {
        if (obj instanceof Timestamp) {
            return obj;
        } else if (obj instanceof String) {
            obj.replace("%3A", ":").replace("%20", " ");
            // check whether the time string is in hh:mm:ss.SSS format
            // if there is contains ".", millisecond is included
            boolean haveMillisecondField = obj.indexOf(".") > 0;
            // also support missing time field
            boolean haveTimeField = obj.indexOf(" ") > 0;

            DateFormat formatter;
            if (haveMillisecondField) {
                formatter = new SimpleDateFormat(GenericExpressionFactory.STANDARD_DATETIMEWITHMILLISEC_FORMAT);
            } else if (haveTimeField) {
                formatter = new SimpleDateFormat(GenericExpressionFactory.STANDARD_DATETIME_FORMAT);
            } else {
                formatter = new SimpleDateFormat(GenericExpressionFactory.STANDARD_DATE_FORMAT);
            }
            Date date = formatter.parse(obj);
            return new Timestamp(date.getTime());
        } else {
            return toTimestamp(obj)
        }
    }

    def Boolean(obj) {
        return Boolean.parseBoolean(obj);
    }

    def psets(TreeNode node, name = '') {
        def n = node;
        while (n) {
            //p "$name ${n.path}: ${n.set}"
            n = n.parent
        }
    }

    // do a count based on node sets--if null, use ds.rowCount
    def count(TreeNode rnode, TreeNode cnode = null) {
        def theSet = and(rnode, cnode)
        theSet ? theSet.cardinality() : ds.rowCount
    }

    def percentOfRowParentCount(DataColumn datacol) {
        def myset = and(rowNode, columnNode)
        def parentset = and(rowNode?.logicalParent, columnNode)
        def mycount = count(rowNode, columnNode)
        def parentcount = count(rowNode?.logicalParent, columnNode)
        parentcount ? mycount * 100d / parentcount : 100
    }


    def distinctCount(DataColumn col) {
        def i = col.iterator(and(rowNode, columnNode))
        def values = new java.util.HashSet()
        i.each { values.add(it) }
        return values.size()
    }

    def sumOverDistinctCount(DataColumn col) {
        // here to fake out GroovyGenerator, which only looks for methods with one arg
        null
    }
    def sumOverDistinctCount(DataColumn colTop, DataColumn colBottom) {
        sum(colTop) / distinctCount(colBottom)
    }

    def Concatenate(Object... list) {
        list.join()
    }

    //
    //  2014-03-19  thorick
    //              before v5.6  'If' is a 3 arg operator
    //              for    v5.6  'IF' is a 2 arg operator with an optional 3rd arg
    //
    def If(condition, ifTrue, ifFalse) {
        IF(condition, ifTrue, ifFalse)
    }

    /////////////////////////////////////////////////
    //
    //  2014-02-14  thorick
    //
    //              UDF  'User Defined Field' Feature specific code
    //
    def cellValues(DataColumn dc) {
        cellValues(dc, "Current");
    }

    def cellValues(DataColumn dc, String level) {
        def bitSet = bitSetForLevel(level);
        return dc.iterator(bitSet);
    }

    //
    //   END   UDF  Feature specific code
    //
    //////////////////////////////////////////////////

    //Least/Greatest
    Object Least(Object... args) {
        if (args==null || args.length==0 || !(args[0] instanceof Comparable)) return null;
        Comparable res=(Comparable)args[0];
        for (int i=1;i<args.length;i++) {
            if (res==null||res.compareTo(args[i])>0)
                res=(Comparable)args[i];
        }
        return res;
    }

    Object Greatest(Object... args) {
        if (args==null || args.length==0 || !(args[0] instanceof Comparable)) return null;
        Comparable res=(Comparable)args[0];
        for (int i=1;i<args.length;i++) {
            if (res==null||res.compareTo(args[i])<0)
                res=(Comparable)args[i];
        }
        return res;
    }

    def hour(date) { // should be joda DateTime
        date.hourOfDay().get()
    }
    def filter(id, hint, expression) {
        expression
    }

    def aggregationFunction(returnType, expression) {
        expression
    }

    def TimeBalanceDefault(DataColumn col){
        TimeBalanceDefault(col, null);
    }

    def TimeBalanceDefault(DataColumn col, String func){
        TimeBalanceDefault(col, func, null);
    }

    def TimeBalanceAverage(DataColumn col, DataColumn dateCol){
        TimeBalanceAverage(col, dateCol, null, null);
    }

    def TimeBalanceLast(DataColumn col, DataColumn dateCol){
        TimeBalanceLast(col, dateCol, null, null);
    }

    def TimeBalanceFirst(DataColumn col, DataColumn dateCol){
        TimeBalanceFirst(col, dateCol, null, null);
    }

    def TimeBalanceAverage(DataColumn col, DataColumn dateCol, String func){
        TimeBalanceAverage(col, dateCol, func, null);
    }

    def TimeBalanceLast(DataColumn col, DataColumn dateCol, String func){
        TimeBalanceLast(col, dateCol, func, null);
    }

    def TimeBalanceFirst(DataColumn col, DataColumn dateCol, String func){
        TimeBalanceFirst(col, dateCol, func, null);
    }

    def TimeBalanceLast(DataColumn col, DataColumn dateCol, String func, String level) {

        def bitSet = bitTimeSetForLevel(columnKey);
        Iterator<Object> itrCol = col.iterator(bitSet);
        Iterator<Object> itrDateCol = dateCol.iterator(bitSet);
        Object val = timebalancelast_java(itrCol, itrDateCol, func, bitSet);
        updateAggregates(col, val, bitSet);
        return val;
    }

    def TimeBalanceFirst(DataColumn col, DataColumn dateCol, String func, String level) {
        def bitSet = bitTimeSetForLevel(columnKey);
       // p("biSet")
       // p(bitSet)
        Iterator<Object> itrCol = col.iterator(bitSet);
        Iterator<Object> itrDateCol = dateCol.iterator(bitSet);
        Object val = timebalancefirst_java(itrCol, itrDateCol, func, bitSet);
        updateAggregates(col, val, bitSet);
        return val;
    }


    def TimeBalanceDefault(DataColumn col, String func, String level) {
        def bitSet = bitTimeSetForLevel(level);
        Iterator<Object> itrCol = col.iterator(bitSet);
        //Iterator<Object> itrDateCol = dateCol.iterator(bitSet);
        return  timebalancedefault_java(itrCol, func, bitSet);
    }


    def TimeBalanceAverage(DataColumn col, DataColumn dateCol, String func, String level) {
        def bitSet = bitTimeSetForLevel(level);
        Iterator<Object> itrCol = col.iterator(bitSet);
        Iterator<Object> itrDateCol = dateCol.iterator(bitSet);
        Object val  = timebalanceaverage_java(itrCol, itrDateCol, func, bitSet);
        updateAggregates(col, val, bitSet);
        return val;
    }
	

    // PRODATO/ERAMON defined function for formatting measure display
    def FormatValueByUnit(double val, String unit, Integer baseParameter) {
        int base = (baseParameter == null || baseParameter == 0) ? 1000 : baseParameter;
        int c = 0;
        double d = val;
        while(d > base){
            d = d/base;
            c++;
        }
        
        String unitPrefix = "";
        double retValue = val;
        if(c == 1){
            unitPrefix = "K";
            retValue = val/base;
        }else if(c == 2){
            unitPrefix = "M";
            retValue = val/base/base;
        }else if(c == 3){
            unitPrefix = "G";
            retValue = val/base/base/base;
        }else if(c == 4){
            unitPrefix = "T";
            retValue = val/base/base/base/base;
        }else if(c > 5){
            unitPrefix = "P";
            retValue = val/base/base/base/base/base;
        }
        
        return (new java.text.DecimalFormat("###,##0.00")).format(retValue) + " " + unitPrefix + unit;
    }
    
    def FormatValueByUnit(double val, String unit) {
        return FormatValueByUnit(val, unit, null);
    }

}
