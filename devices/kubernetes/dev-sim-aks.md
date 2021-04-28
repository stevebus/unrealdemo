# Simulate devices with mock-devices and the Azure Kubernetes Service

If you don't have, or don't want to install, Docker Desktop and want to keep your simulation running, you can deploy it in a workload in [Azure Kubernetes Service](https://docs.microsoft.com/en-us/azure/aks/).

This guide gives step by step instructions on setting up a very basic single-node AKS cluster and getting the mock-devices simulator running on it with our pre-built device simulation configuration, but does not cover the basic AKS or Kubernetes concepts. For those, refer to the documention linked above.

This guide also assumes you already have the mock-devices UI application installed via the previous [simulate iot devices](/docs/simulate-iot-devices.md) documentation.  We will use this user interface to manage our AKS hosted mock-devices engine

## Install the Azure CLI

This guide leverages the Azure command-line interface (CLI).  If you haven't already installed the CLI, you can do so from [here](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli), or alternately, you can leverage the CLI from an Azure Cloud Shell, as described [here](https://docs.microsoft.com/en-us/azure/cloud-shell/overview).  Either option is fine. For the commands below, we use a 'bash' shell.

## Set up AKS cluster

The first step in setting up an AKS cluster is to create a resource group to contain the AKS resources. You can reuse an existing group, or create a new one. To create a new one, run the command

``` bash
    az group create -n <group name> --location <location>
```

where \<location> is the 'name' of the Azure region you want to use for your deployment, for example 'eastus2'  (you can obtain a list of valid Azure locations by running `az account list-locations -o table`)

Now let's create our AKS cluster.  To create one, run this command

```bash
    az aks create --resource-group <group name> --name <cluster name> --node-count 1 --generate-ssh-keys
```

For \<cluster name>, use a name that should be universally unique.  Note that, for cost reasons, we are using a 'node count' of 1. If you want to ensure high-availability of your device simulations, you should use a node count of 2 or greater.

Creating the cluster will take several minutes.  Once this is done, we want to manage our cluster. AKS clusters can be managed with any compatible Kubernetes cluster management solution. For simplicity, we will use the very popular [kubectl](https://kubernetes.io/docs/reference/kubectl/overview/) command line.

To install kubectl on your machine (or cloud shell), run

```bash
    az aks install-cli
```

Once installed, we need to configure kubectl to point to, and authenticate to, our AKS cluster

```bash
    az aks get-credentials --resource-group <group name> --name <cluster name>
```

This downloads the ssh credentials you created when you created your cluster and configures kubectl to use them.

To confirm success to this point, run

```bash
    kubectl get nodes
```

You should see something similar to this

![kubectl get pods](/media/kubectl-confirmation.jpg)

This shows that we have a single node running in our cluster and that we are successfully administering it.

## Deploy mock-devices

The next step is to deploy the mock-devices docker container as a workload on our AKS cluster. The deployment configuration YAML file to do so is already included [here](deploymockdevices.yaml) in this repo. Download that file to your desktop (and upload to your cloud shell if you are using one).

The YAML file includes both the mock-devices container, as well as an _nginx_ proxy as a load balancer. This is necessary to expose the mock-devices configuration REST API externally for our cluster

>NOTE Because this is a dev/test test scenario only, we are deploying this API with no authentication. Do not do this in production.  Rather, refer to the to How-to-guides->Security and Authentication portions of the [AKS documentation](https://docs.microsoft.com/en-us/azure/aks/)

To deploy the mock-devices container, run

```bash
    kubectl apply -f <path to deploymockdevices.yaml>
```

That will begin the deployment process of the load balancer and the mock-devices container. You can check on the status by running

```bash
    kubectl get pods
```

Initially, you will probably see a 'ContainerCreating...' status as shown below

![container creating](/media/kubectl-get-pods.jpg)

Re-running the `kubectl get pods` command should eventually give you a 'Running' status

![container running](/media/kubectl-get-pods-running.jpg)

You can also check on the status of the load balancer by running

```bash
    kubectl get services
```

That will show you the running load balancer.  

![running load balancer](/media/kubectl-get-services.jpg)

Make note of the IP address returned, as you will use it to invoke the configuration APIs of the mock-devices containers.

## Configure mock-devices

The mock-devices container is now running, but is idle waiting on configuration.

To configure, start the mock-devices engine (npm run app from the mock-devices folder).  Once you start the UI, click the UX button in the lower left hand corner

![mock-devices ux](/media/mock-devices-ux-button.jpg)

This will bring up the dialog to point your mock-devices UI at the AKS hosted version of your engine.  Enter ```http://<aks external ip>:8989``` as the server+port and choose "UX" as the type as shown below

![mock devices aks config](/media/mock-devices-aks-config.jpg)

Click on "Change" to save your changes.  Right below the console window, you should see that the UI is configured to point to the cluster IP address

Now we can manage the devices in AKS.  This process is very similar to managing locally with one exception. Click on the +Add/Save button and, instead of clicking "load/save from file system", click "Editor"  (we can't load or save from file system, since the engine is running in the cloud).

Open up the [mock-devices-template](/devices/mock-devices-template.json) file in your favorite editor, select the entire file, and paste its contents into the Editor window (as shown below) and click "Update Current State"

![update current state](/media/mock-devices-editor.jpg)

At this point you should see our list of simulated devices and the experience is the same as running interactively.  You can start and stop simulations, etc.

___The one exception is that now you can exit the UI and your simulation will continue running!!___  At any time in the future, you can re-run the mock-devices UI, reconnect it to your cluster IP address and port, and pick up where you left off

>NOTE Even though the mock-devices engine can run in a container and continue running when not connected to the UI, it does not re-start the simulations if the container should reboot. If the container restarts for any reason, you'll need to restart the simulation by connecting via the GUI and restarting

## Verify success

You can verify success in two steps  (if you aren't interested in the container details, you can skip the first step)

### 1) Look at container logs

You can view the 'docker logs' for the mock-devices container.

As before, run `kubectl get pods` to get the name of your container pod, as below

![get pods](/media/kubectl-get-pods.jpg)

Once you have that, run

```bash
kubectl logs -f <pod name>
```

where \<pod name> is the name of your pod returned above.  For example:

![container logs](/media/kubectl-logs.jpg)

In the logs you can see the logging output of the mock-devices container, including (circled) where it has started sending temperature data

### 2) check your IoT Hub

In the Azure CLI, you can monitor the data flowing into the IoT Hub you created as part of your solution  (if you don't remember the name you can run `az iot hub list -o table`).  To monitor the data flowing into your IoT Hub, you can run

```bash
az iot hub monitor-events -n <iot hub name> -t 0
```

where \<iot hub name> is the short name of your IoT Hub (without the .azure-devices.net)

You will see an output similar to this (with the name of our IoT Hub blacked out)

![iot hub messages](/media/iothub-monitor-events.jpg)

If it's the first time you've run this command, you may be prompted to install the amqp libraries.  Answer yes.

### 3) Verify your end-to-end solution

If the rest of your solution is up and running, you should see updates flowing through Azure to your Unreal application.

## Starting/Stoping cluster

If, for cost or any other reason, you don't want your AKS cluster to run all the time, you can stop and start it whenever you wish. To do so, follow [these instructions](https://microsoft.github.io/AzureTipsAndTricks/blog/tip308.html)
