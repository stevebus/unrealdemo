import { PlugIn } from '../interfaces/plugin'

// This class name is used in the device configuration and UX
export class hvac implements PlugIn {

    // Sample code
    private devices = {};
//    private currentTemp = 0;
//    private tempGoingUp = true;
    private possibleAirflows=[0,500,1000];
//    private currentAirflow = this.possibleAirflows[0];
//    private devState;
    private deviceState = new Map();

    // this is used by the UX to show some information about the plugin
    public usage: string = "This is a sample plugin that will provide an integer that decrements by 1 on every loop or manual send. Acts on the device for all capabilities"

    // this is called when mock-devices first starts. time hear adds to start up time
    public initialize = () => {
        
        return undefined;
    }

    // not implemented
    public reset = () => {
        return undefined;
    }

    // this is called when a device is added or it's configuration has changed i.e. one of the capabilities has changed
    public configureDevice = (deviceId: string, running: boolean) => {
        if (!running) {
            this.devices[deviceId] = {};
        }
        if(!this.deviceState.has(deviceId))
        {
            this.deviceState.set(deviceId,
                {
                    currAirFlow: this.possibleAirflows[0], 
                    currTemp: 0,
                    currGoingUp: true
                });
        }
    }

    // this is called when a device has gone through dps/hub connection cycles and is ready to send data
    public postConnect = (deviceId: string) => {
        return undefined;
    }

    // this is called when a device has fully stopped sending data
    public stopDevice = (deviceId: string) => {
        return undefined;
    }

    // this is called during the loop cycle for a given capability or if Send is pressed in UX
    public propertyResponse = (deviceId: string, capability: any, payload: any) => {
        // if (Object.getOwnPropertyNames(this.devices[deviceId]).indexOf(capability._id) > -1) {
        //     this.devices[deviceId][capability._id] = this.devices[deviceId][capability._id] - 1;
        //     this.devices[deviceId][capability._id]
        // } else {

//        var temp = 0;
        var value = JSON.parse(payload);
        var devState = this.deviceState.get(deviceId);
        var currTemp = devState.currTemp;
        var currAirFlow = devState.currAirFlow;
        var currGoingUp = devState.currGoingUp;     

        if(value.type === 'temp')
        {
            var min=value.min;
            var max=value.max;
            var increment = value.increment;

            //console.log('payload=' + payload + ', min= ' + value.min + ', max=' + value.max+ ', increment=' + value.increment);

            //set initial temp state to min
            if(currTemp < min)
            {
                currTemp = min;
                currGoingUp = true;
            }

            if(currGoingUp === true)
            {
                currTemp = currTemp + increment;
                if(currTemp > max)
                {
                    currTemp=max;
                    currGoingUp=false;
                }
            }
            else
            {
                currTemp = currTemp - increment;
                if(currTemp < min)
                {
                    currTemp=min;
                    currGoingUp=true;
                }
            }

            this.devices[deviceId][capability._id] = currTemp;
            //this.currentTemp = temp;
        }
        else if (value.type === 'airflow')
        {
            switch (true)
            {
                case (currTemp > value.off):
                    currAirFlow = this.possibleAirflows[0];
                    break;
                case ((currTemp > value.medium) && (currTemp <= value.off)):
                    currAirFlow = this.possibleAirflows[1];
                    break;
                case (currTemp <= value.medium):
                    currAirFlow = this.possibleAirflows[2];
                    break;
                default:
                    currAirFlow = this.possibleAirflows[0];
            }
            this.devices[deviceId][capability._id] = currAirFlow;
        }
        else
        {
            console.log('bad hvac data type:' + value.type);
        }

//        this.devices[deviceId][capability._id] = (Math.random() * 100);
        this.deviceState.set(deviceId,
            {
                currAirFlow: currAirFlow, 
                currTemp: currTemp,
                currGoingUp: currGoingUp
            });
            
        // }
        return this.devices[deviceId][capability._id];
    }

    // this is called when the device is sent a C2D Command or Direct Method
    public commandResponse = (deviceId: string, capability: any) => {
        return undefined;
    }

    // this is called when the device is sent a desired twin property
    public desiredResponse = (deviceId: string, capability: any) => {
        return undefined;
    }
}