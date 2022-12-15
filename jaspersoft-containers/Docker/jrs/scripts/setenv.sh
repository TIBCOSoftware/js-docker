#export JAVA_OPTS="$JAVA_OPTS -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:8000"
export JAVA_OPTS="$JAVA_OPTS -Djava.net.preferIPv4Stack=true"

# Http Client debug (didn't work)
#export JAVA_OPTS="$JAVA_OPTS -Dorg.apache.commons.logging.Log=org.apache.commons.logging.impl.SimpleLog"
#export JAVA_OPTS="$JAVA_OPTS -Dorg.apache.commons.logging.simplelog.showdatetime=true"
#export JAVA_OPTS="$JAVA_OPTS -Dorg.apache.commons.logging.simplelog.log.org.apache.http=DEBUG"
#export JAVA_OPTS="$JAVA_OPTS -Dorg.apache.commons.logging.simplelog.log.org.apache.http.wire=ERROR"
