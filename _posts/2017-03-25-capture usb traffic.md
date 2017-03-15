---
layout: post
title: Capture USB traffic and use LibUSB to mimic host - device communications (Vala / Luxafor)
subtitle: 
---

# Purpose

I have [Luxafor](http://www.luxafor.fr/products/) device and I want to play with it. I know that there's at least two libraries, written for [nodejs](https://github.com/iamthefox/luxafor) and for [python](https://github.com/vmitchell85/luxafor-python). But the challenge here is to face a problem and resolve it. After all, it doesn't look so hard, it's basically binary data sent over an USB device.

Sadly, Luxafor only provides softwares for Macos and Windows. As it's much easier to sniff USB traffic on Windows than on Linux, let's go on Windows. 

# Sniff USB traffic (on Windows, but not really)

I thought that I'll install a Windows for that purpose, but I definitively abandoned that idea. No way. So, let's say there's an official Luxafor client for Ubuntu. 

## Install Wireshark

{% highlight bash %}
$ sudo install wireshark
{% endhighlight %}

## Load usbmon Kernel module

{% highlight bash %}
$ sudo modprobe usbmon
{% endhighlight %}

## Start wireshark

{% highlight bash %}
$ sudo wireshark
{% endhighlight %}

## Find in which monitor the Luxafor is pluggued

When Wireshark starts, you'll see the live traffic on each interfaces that can be sniffed by the tool. The __usbmon2__ traffic pike matches exactly the time when I pluggued the device :

![interfaces]({{ site.url }}/assets/2017-03-25/wireshark-interfaces.png)

### Capture when I change the Luxafor color

__Double-click on usbmon2__

![Ready to listen]({{ site.url }}/assets/2017-03-25/wireshark-ready.png)

__Activate the Luxafor color RED__

For that purpose, consider [my own luxafor-cli written in Vala](https://github.com/lcallarec/luxafor-cli/), or try this [nodejs](https://github.com/iamthefox/luxafor) script else this [python](https://github.com/vmitchell85/luxafor-python) script.

{% highlight bash %}
$ sudo ./luxafor color --red=255
{% endhighlight %}

__Analyze the payload__

When the Luxafor change to red, Wireshark has sniffed you packets :

![Sniff]({{ site.url }}/assets/2017-03-25/wireshark-sniff.png)

The most important information is the URB_INTERUPT packet sent from host to USB device. The leftover capture data are the actual data that have been sent to the USB device. 

{% highlight R %}
01 ff ff 00 00 00 00
{% endhighlight %}

Bingo !

* The packet sent is seven 8-bits data long
* There's two `ff`. Does one of them color be the `255` (`0xff`) I set for the red channel, if there's a red channel ? Simple test : what if I switch color to `-red=255, --green=127, --blue=64` ? If I'm guessing right, Luxafor should sniff these hexadecimal values 

{% highlight R %}
ff 7f 40
{% endhighlight %}

Let's try :

{% highlight bash %}
$ sudo ./luxafor color --red=255 --green=127 --blue=64
{% endhighlight %}

Guess what :

![Sniff again]({{ site.url }}/assets/2017-03-25/wireshark-sniff-2.png)

{% highlight R %}
01 ff ff 7f 40 00 00
{% endhighlight %}

* third byte is for the red channel
* fourth byte is for the green channel
* fifth byte is for the red channel

I still don't know what other bytes are for.

## Unload usbmon Kernel module

To clore your monitoring session in a clean way,, unload the __usbmod__ module :

{% highlight bash %}
$ sudo modprobe -r usbmon
{% endhighlight %}

# Write a Vala script that does the job

Before I strat, I read chunks of documentation from [LibUSB](http://libusb.info/). I learnt that Prior to connect to an USB device, I need to find the vendorID and productID of the Luxafor device.

## Find USB vendorID / productID

Capture with `lusb` command the list of connected device - with the Luxafor un-plugged, and re-fetch the list with the Luxafor plugged to guess which one is the device you're looking for : 

{% highlight bash %}
$ lsusb
Bus 002 Device 005: ID 04d8:f372 Microchip Technology, Inc. 
{% endhighlight %}

`04d8:f372` are respectively vendorID and productID information we're looking for. Nice.

{% highlight bash %}
$ lsusb -vd 04d8:f372

Bus 002 Device 005: ID 04d8:f372 Microchip Technology, Inc. 
Couldn't open device, some information will be missing
Device Descriptor:
  bLength                18
  bDescriptorType         1
  bcdUSB               2.00
  bDeviceClass            0 (Defined at Interface level)
  bDeviceSubClass         0 
  bDeviceProtocol         0 
  bMaxPacketSize0         8
  idVendor           0x04d8 Microchip Technology, Inc.
  idProduct          0xf372 
  bcdDevice            0.01
  iManufacturer           1 
  iProduct                2 
  iSerial                 0 
  bNumConfigurations      1
  Configuration Descriptor:
    bLength                 9
    bDescriptorType         2
    wTotalLength           41
    bNumInterfaces          1
    bConfigurationValue     1
    iConfiguration          0 
    bmAttributes         0xa0
      (Bus Powered)
      Remote Wakeup
    MaxPower              160mA
    # ...
{% endhighlight %}

# LibUSB

I decided to use Vala as language to write the  POC: it remaing very close to C APIs, is far faster to write and much more readble than C.

## Install Vala and other dependencies

On an apt package manager based system :
{% highlight bash %}
$ sudo apt-get install vala libusb-1.0-0 libusb-1.0-0-dev libusb-dev
{% endhighlight %}

## Vala code

main.vala :
{% highlight vala %}

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
			handle.bulk_transfer(1, {0x01, 0xff, 0xff, 0x7f, 0x40, 0x00, 0x00}, out len, 10);
		}
	}

	return 0;
}

{% endhighlight %}

## Compile and run

Compile :
{% highlight bash %}
$ valac --pkg libusb-1.0 main.vala -o usb
{% endhighlight %}

Run :
{% highlight bash %}
$ sudo ./usb
{% endhighlight %}

# Bingo !

The --Luxafor__ color is now `--red=255 --green=127 --blue=64`, as expected !
