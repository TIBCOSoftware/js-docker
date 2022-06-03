This chart used for scalable query engine custom scaling

Follow below steps to enable the custom scaling
1. Delete the default Horizontal Pod Autoscaler for scalable query engine 

    
    kubectl get hpa
    kubectl delete hpa <scalable-query-engine-hpa name>
1. Change the `queryEngine.deployment` if any thing changed
1. Run  `helm dep update`   
1. Run `helm install customscaling .  `
1. Check the new HPA by running `kubectl get hpa`