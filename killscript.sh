# Define namespace
namespace="longhorn-system"

# Get all pods in Terminated / Evicted State
epods=$(kubectl get pods -n ${namespace} | grep -E -i 'Terminating|Evicted' | awk '{print $1 }')
echo ${epods}

# Force deletion of the pods
for pod in ${epods[@]}; do
  echo "deleting $(pod)"
  kubectl delete pod --force=true --wait=false --grace-period=0 $pod -n ${namespace}
done
