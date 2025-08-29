# 🚀 Blue-Green Deployment on EKS - SIMPLE SETUP

## 📋 What You Need
- ✅ EKS cluster: `bluegreen-eks-sbx` (you have this)
- ✅ Namespace: `sbx` (you have this)
- ✅ kubectl, docker, aws cli installed

## 🎯 ONE COMMAND SETUP

```bash
chmod +x COMPLETE-SETUP.sh && ./COMPLETE-SETUP.sh
```

**That's it!** This single command will:
1. ✅ Check prerequisites
2. ✅ Configure kubectl
3. ✅ Build Docker images
4. ✅ Deploy everything to Kubernetes
5. ✅ Wait for deployments to be ready
6. ✅ Test the application

## 🔄 After Setup - How to Use Blue-Green Deployment

### Test Your Application
```bash
kubectl port-forward service/bluegreen-demo-service 8080:80 -n sbx
# Open browser: http://localhost:8080
```

### Switch Between Versions
```bash
# Switch to GREEN version
kubectl patch service bluegreen-demo-service -n sbx -p '{"spec":{"selector":{"version":"green"}}}'

# Switch to BLUE version  
kubectl patch service bluegreen-demo-service -n sbx -p '{"spec":{"selector":{"version":"blue"}}}'
```

### Check Status
```bash
kubectl get all -n sbx
```

### Clean Up When Done
```bash
kubectl delete -f k8s/
```

## 🎯 What Gets Deployed

- **2 Deployments**: `bluegreen-demo-blue` and `bluegreen-demo-green`
- **3 Services**: Main service + blue service + green service  
- **1 Ingress**: For external access
- **6 Pods**: 3 blue + 3 green (with replicas)

## 🔧 If Something Goes Wrong

1. **Check pod status**: `kubectl get pods -n sbx`
2. **Check logs**: `kubectl logs -l app=bluegreen-demo -n sbx`
3. **Restart setup**: `kubectl delete -f k8s/ && ./COMPLETE-SETUP.sh`

---

**Everything is pre-configured for your existing setup!** 
Just run the single command above and you're done! 🎉
