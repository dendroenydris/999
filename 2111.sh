# Constants
PROJECT_ID="cloudcomputingg4"
ZONE="us-central1-a" # Update with the correct zone
MASTER_INSTANCE="controller-lucca"
WORKER1_INSTANCE="compute1-lucca"
WORKER2_INSTANCE="compute2-lucca"
SPARK_VERSION="3.4.4"
SPARK_DOWNLOAD_URL="https://downloads.apache.org/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop3.tgz"
SPARK_HOME="/opt/spark"
LOG_DIR="$HOME/spark_logs"
JAVA_PACKAGE="openjdk-8-jdk"

# Start Spark Master
start_master() {
  echo "Starting Spark Master on $MASTER_INSTANCE..."
  gcloud compute ssh $MASTER_INSTANCE --zone=$ZONE --project=$PROJECT_ID --command "cat $SPARK_HOME/sbin/start-master.sh"
  gcloud compute ssh $MASTER_INSTANCE --zone=$ZONE --project=$PROJECT_ID --command "$SPARK_HOME/sbin/start-master.sh"
}

# Start Spark Worker
start_worker() {
  local INSTANCE=$1
  local MASTER_IP=$2
  echo "Starting Spark Worker on $INSTANCE..."
  gcloud compute ssh $INSTANCE --zone=$ZONE --project=$PROJECT_ID --command "$SPARK_HOME/sbin/start-worker.sh spark://$MASTER_IP:7077"
}

# Run Spark Job
run_spark_job() {
  echo "Running JavaSparkPi job on the Master..."
  gcloud compute ssh $MASTER_INSTANCE --zone=$ZONE --project=$PROJECT_ID --command "\
    $SPARK_HOME/bin/spark-submit \
      --class org.apache.spark.examples.JavaSparkPi \
      --master spark://$(get_master_ip):7077 \
      $SPARK_HOME/examples/jars/spark-examples_2.12-${SPARK_VERSION}.jar \
      500"
}

# Get Master IP
get_master_ip() {
  gcloud compute instances describe $MASTER_INSTANCE --zone=$ZONE --project=$PROJECT_ID \
    --format="get(networkInterfaces[0].accessConfigs[0].natIP)"
}

# Collect Logs
collect_logs() {
  echo "Collecting logs..."
  sudo mkdir -p /opt/spark/logs

  # Collect Master logs
  gcloud compute scp --zone=$ZONE $MASTER_INSTANCE:$SPARK_HOME/logs/spark-*-master*.out $LOG_DIR/master-spark.log --project=$PROJECT_ID
  
  # Collect Worker logs
  gcloud compute scp --zone=$ZONE $WORKER1_INSTANCE:$SPARK_HOME/logs/spark-*-worker*.out $LOG_DIR/worker1-spark.log --project=$PROJECT_ID
  gcloud compute scp --zone=$ZONE $WORKER2_INSTANCE:$SPARK_HOME/logs/spark-*-worker*.out $LOG_DIR/worker2-spark.log --project=$PROJECT_ID
}

# Main Script
echo "Starting Spark Cluster Setup..."

# 1. Install dependencies and Spark on all instances
# for INSTANCE in $MASTER_INSTANCE $WORKER1_INSTANCE $WORKER2_INSTANCE; do
#   gcloud compute ssh $INSTANCE --zone=$ZONE --project=$PROJECT_ID --command "$(typeset -f); install_dependencies; install_spark"
# done

# 2. Start Master
start_master

# 3. Start Workers
MASTER_IP=$(get_master_ip)
start_worker $WORKER1_INSTANCE $MASTER_IP
start_worker $WORKER2_INSTANCE $MASTER_IP

# 4. Run Spark Job
run_spark_job

# 5. Collect Logs
collect_logs

echo "Setup Complete! Logs are available in $LOG_DIR."
