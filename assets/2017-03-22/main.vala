int main(string[] args)
{
	LibUSB.Context context;
	LibUSB.Device[] devices;
	LibUSB.DeviceHandle handle;
	LibUSB.Device? luxafor = null;

	LibUSB.Context.init(out context);
	context.get_device_list (out devices);
	
	int i = 0;
	while (devices[i] != null)
	{
		var dev = devices[i];
		LibUSB.DeviceDescriptor desc = LibUSB.DeviceDescriptor (dev);
		if (desc.idVendor == 0x04d8 && desc.idProduct == 0xf372)
		{
			luxafor = dev;
			break;
		}
		i++;
	}		

	if (null != luxafor) 
	{

		int result = luxafor.open(out handle);
		if (result != 0) {
			return 1;
		}

		handle.detach_kernel_driver(0);
				
		int retries = 1000;
		int claim_device_result;
		while ((claim_device_result = handle.claim_interface(0)) != 0 && retries-- > 0) {
			handle.detach_kernel_driver(0);
		}

		if (claim_device_result == 0)
		{
			int len;
			handle.bulk_transfer(1, {0x01, 0xff, 0xff, 0x7f, 0xff, 0x00, 0x00}, out len, 10);
		}
	}

	return 0;
}
			
