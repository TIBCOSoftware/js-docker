#!/bin/bash
#
# script to run export-import command
#

# Collect the command line args

CMD_LINE_ARGS=$*


# Set the main config folder to use and collect all
# the jars onto the classpath
#
# If Pro config exists, then set to Pro config
# Otherwise, assume CE config

if test -d $BASEDIR/conf_source/iePro
then
    echo "Executing Pro version"
    export CONFIG_DIR=$BASEDIR/conf_source/iePro
    for i in $CONFIG_DIR/lib/*.jar
    do
        EXP_CLASSPATH="$EXP_CLASSPATH:$i"
    done

else
    echo "Executing CE version"
    export CONFIG_DIR=$BASEDIR/conf_source/ieCe
    for i in $CONFIG_DIR/lib/*.jar
    do
        EXP_CLASSPATH="$EXP_CLASSPATH:$i"
    done
fi

# Additional config folder. This will be used to 
# get js.jdbc.properties from buildomatic setup
export ADDITIONAL_CONFIG_DIR=$BASEDIR/build_conf/default


# Locate the java binary bundled with installer
#
# If "../java/bin/java" exists, use it

JAVA_EXEC=java

if test -f $BASEDIR/../java/bin/java
then
    echo "Using Bundled version of Java" 
    JAVA_HOME=$BASEDIR/../java
    PATH=$JAVA_HOME/bin:$PATH
    JAVA_EXEC=$JAVA_HOME/bin/java
fi

export BUILDOMATIC_MODE=${BUILDOMATIC_MODE:-interactive}

# Add the java memory options to JAVA_OPTS if none given
if [ [ $JAVA_OPTS != *"-Xmx"* ] && [ $JAVA_OPTS != *"UseContainerSupport"* ] ]; then
  export JAVA_OPTS="$JAVA_OPTS -Xms128m -Xmx512m"
fi

export JAVA_OPTS="$JAVA_OPTS -Djava.net.preferIPv4Stack=true -noverify"
#export JAVA_OPTS="$JAVA_OPTS -Xrunjdwp:transport=dt_socket,server=y,suspend=y,address=5005"

# Add the config folders to EXP_CLASSPATH

export EXP_CLASSPATH="$CONFIG_DIR:$ADDITIONAL_CONFIG_DIR$EXP_CLASSPATH:."

# run java

$JAVA_EXEC -cp "$EXP_CLASSPATH" $JAVA_OPTS $JS_EXP_CMD_CLASS $JS_CMD_NAME $CMD_LINE_ARGS

