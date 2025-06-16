package com.well.alcohol.elite.service;

import android.app.Service;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothGatt;
import android.bluetooth.BluetoothGattCallback;
import android.bluetooth.BluetoothGattCharacteristic;
import android.bluetooth.BluetoothGattDescriptor;
import android.bluetooth.BluetoothGattService;
import android.bluetooth.BluetoothManager;
import android.content.Intent;
import android.os.Binder;
import android.os.IBinder;
import android.util.Log;
import com.well.alcohol.elite.util.e;
import com.well.alcohol.elite.util.g;
import java.util.List;
import java.util.UUID;

/* loaded from: classes.dex */
public class UartService extends Service {

    /* renamed from: a, reason: collision with root package name */
    private static final String f930a = UartService.class.getSimpleName();

    /* renamed from: b, reason: collision with root package name */
    public static final UUID f931b = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb");

    /* renamed from: c, reason: collision with root package name */
    public static final UUID f932c = UUID.fromString("6e400001-b5a3-f393-e0a9-e50e24dcca9e");
    public static final UUID d = UUID.fromString("6e400002-b5a3-f393-e0a9-e50e24dcca9e");
    public static final UUID e = UUID.fromString("6e400003-b5a3-f393-e0a9-e50e24dcca9e");
    private BluetoothManager f;
    private BluetoothAdapter g;
    private String h;
    private BluetoothGatt i;
    private String l;
    private String m;
    private int j = 0;
    private StringBuffer k = new StringBuffer("");
    private final BluetoothGattCallback n = new a();
    private StringBuffer o = new StringBuffer("");
    private final IBinder p = new b();

    class a extends BluetoothGattCallback {
        a() {
        }

        @Override // android.bluetooth.BluetoothGattCallback
        public void onCharacteristicChanged(BluetoothGatt bluetoothGatt, BluetoothGattCharacteristic bluetoothGattCharacteristic) {
            UartService.this.g("com.nordicsemi.nrfUART.ACTION_DATA_AVAILABLE", bluetoothGattCharacteristic);
        }

        @Override // android.bluetooth.BluetoothGattCallback
        public void onCharacteristicRead(BluetoothGatt bluetoothGatt, BluetoothGattCharacteristic bluetoothGattCharacteristic, int i) {
            if (i == 0) {
                UartService.this.g("com.nordicsemi.nrfUART.ACTION_DATA_AVAILABLE", bluetoothGattCharacteristic);
            }
        }

        @Override // android.bluetooth.BluetoothGattCallback
        public void onConnectionStateChange(BluetoothGatt bluetoothGatt, int i, int i2) {
            if (i2 != 2) {
                if (i2 == 0) {
                    UartService.this.j = 0;
                    Log.i(UartService.f930a, "Disconnected from GATT server.");
                    UartService.this.f("com.nordicsemi.nrfUART.ACTION_GATT_DISCONNECTED");
                    return;
                }
                return;
            }
            UartService.this.j = 2;
            UartService.this.f("com.nordicsemi.nrfUART.ACTION_GATT_CONNECTED");
            Log.i(UartService.f930a, "Connected to GATT server.");
            Log.i(UartService.f930a, "Attempting to start service discovery:" + UartService.this.i.discoverServices());
        }

        @Override // android.bluetooth.BluetoothGattCallback
        public void onServicesDiscovered(BluetoothGatt bluetoothGatt, int i) {
            String str = UartService.f930a;
            if (i != 0) {
                Log.w(str, "onServicesDiscovered received: " + i);
                return;
            }
            Log.w(str, "mBluetoothGatt = " + UartService.this.i);
            UartService.this.f("com.nordicsemi.nrfUART.ACTION_GATT_SERVICES_DISCOVERED");
        }
    }

    public class b extends Binder {
        public b() {
        }

        public UartService a() {
            return UartService.this;
        }
    }

    /* JADX INFO: Access modifiers changed from: private */
    public void f(String str) {
        sendBroadcast(new Intent(str));
    }

    /* JADX INFO: Access modifiers changed from: private */
    public void g(String str, BluetoothGattCharacteristic bluetoothGattCharacteristic) {
        Intent intent = new Intent(str);
        this.o.append(e.b(bluetoothGattCharacteristic.getValue()));
        g.a("broadcastUpdate---------------------start=" + ((Object) this.o));
        StringBuffer stringBuffer = this.o;
        if (stringBuffer == null || stringBuffer.length() <= 0) {
            return;
        }
        int i = 0;
        for (int i2 = 0; i2 < this.o.length(); i2++) {
            if ("68".equals(this.o.substring(i2, i2 + 2))) {
                i = i2;
            }
            g.a("for---------------------start=" + i);
            int i3 = i * 2;
            int i4 = i3 * 7;
            if ("68".equals(this.o.substring(i4, i4 + 2))) {
                this.k.append(this.o.substring(i3, 18));
                int iD = e.d(this.o.substring(18, 22)) * 2;
                int i5 = iD + 22;
                this.k.append(this.o.substring(18, i5));
                this.l = e.f(this.k.toString()).toUpperCase();
                int i6 = iD + 24;
                String upperCase = this.o.substring(i5, i6).toUpperCase();
                this.m = upperCase;
                if (this.l.equals(upperCase)) {
                    this.k.append(this.l);
                    if (this.o.length() < i6 + 2) {
                        this.k = new StringBuffer("");
                        return;
                    }
                    String strSubstring = this.o.substring(i6, iD + 26);
                    if ("16".equals(strSubstring)) {
                        this.k.append(strSubstring);
                        StringBuffer stringBuffer2 = this.o;
                        stringBuffer2.delete(i, stringBuffer2.toString().length());
                        intent.putExtra("com.nordicsemi.nrfUART.EXTRA_DATA", this.k.toString().toUpperCase().replace(" ", ""));
                        intent.putExtra("com.example.bluetooth.le.EXTRA_DATA_CHARACTERISTIC", bluetoothGattCharacteristic.getUuid().toString());
                        sendBroadcast(intent);
                        this.k = new StringBuffer("");
                        return;
                    }
                } else {
                    continue;
                }
            }
        }
    }

    private void n(String str) {
        Log.e(f930a, str);
    }

    public void h() {
        if (this.i == null) {
            return;
        }
        Log.w(f930a, "mBluetoothGatt closed");
        this.h = null;
        this.i.close();
        this.i = null;
    }

    public boolean i(String str) {
        String str2;
        String str3;
        if (this.g == null || str == null) {
            str2 = f930a;
            str3 = "BluetoothAdapter not initialized or unspecified address.";
        } else {
            String str4 = this.h;
            if (str4 != null && str.equals(str4) && this.i != null) {
                Log.d(f930a, "Trying to use an existing mBluetoothGatt for connection.");
                if (!this.i.connect()) {
                    return false;
                }
                this.j = 1;
                return true;
            }
            BluetoothDevice remoteDevice = this.g.getRemoteDevice(str);
            if (remoteDevice != null) {
                this.i = remoteDevice.connectGatt(this, false, this.n);
                Log.d(f930a, "Trying to create a new connection.");
                this.h = str;
                this.j = 1;
                return true;
            }
            str2 = f930a;
            str3 = "Device not found.  Unable to connect.";
        }
        Log.w(str2, str3);
        return false;
    }

    public void j() {
        BluetoothGatt bluetoothGatt;
        if (this.g == null || (bluetoothGatt = this.i) == null) {
            Log.w(f930a, "BluetoothAdapter not initialized");
        } else {
            bluetoothGatt.disconnect();
        }
    }

    public void k() {
        BluetoothGattService service = this.i.getService(f932c);
        if (service == null) {
            n("Rx service not found!");
            f("com.nordicsemi.nrfUART.DEVICE_DOES_NOT_SUPPORT_UART");
            return;
        }
        BluetoothGattCharacteristic characteristic = service.getCharacteristic(e);
        if (characteristic == null) {
            n("Tx charateristic not found!");
            f("com.nordicsemi.nrfUART.DEVICE_DOES_NOT_SUPPORT_UART");
        } else {
            this.i.setCharacteristicNotification(characteristic, true);
            BluetoothGattDescriptor descriptor = characteristic.getDescriptor(f931b);
            descriptor.setValue(BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE);
            this.i.writeDescriptor(descriptor);
        }
    }

    public List<BluetoothGattService> l() {
        BluetoothGatt bluetoothGatt = this.i;
        if (bluetoothGatt == null) {
            return null;
        }
        return bluetoothGatt.getServices();
    }

    /* JADX WARN: Removed duplicated region for block: B:9:0x0019  */
    /*
        Code decompiled incorrectly, please refer to instructions dump.
        To view partially-correct code enable 'Show inconsistent code' option in preferences
    */
    public boolean m() {
        /*
            r3 = this;
            android.bluetooth.BluetoothManager r0 = r3.f
            r1 = 0
            if (r0 != 0) goto L19
            java.lang.String r0 = "bluetooth"
            java.lang.Object r0 = r3.getSystemService(r0)
            android.bluetooth.BluetoothManager r0 = (android.bluetooth.BluetoothManager) r0
            r3.f = r0
            if (r0 != 0) goto L19
            java.lang.String r0 = com.well.alcohol.elite.service.UartService.f930a
            java.lang.String r2 = "Unable to initialize BluetoothManager."
        L15:
            android.util.Log.e(r0, r2)
            return r1
        L19:
            android.bluetooth.BluetoothManager r0 = r3.f
            android.bluetooth.BluetoothAdapter r0 = r0.getAdapter()
            r3.g = r0
            if (r0 != 0) goto L28
            java.lang.String r0 = com.well.alcohol.elite.service.UartService.f930a
            java.lang.String r2 = "Unable to obtain a BluetoothAdapter."
            goto L15
        L28:
            r0 = 1
            return r0
        */
        throw new UnsupportedOperationException("Method not decompiled: com.well.alcohol.elite.service.UartService.m():boolean");
    }

    public void o(byte[] bArr) {
        BluetoothGattService service = this.i.getService(f932c);
        n("mBluetoothGatt null" + this.i);
        if (service == null) {
            n("Rx service not found!");
            f("com.nordicsemi.nrfUART.DEVICE_DOES_NOT_SUPPORT_UART");
            return;
        }
        BluetoothGattCharacteristic characteristic = service.getCharacteristic(d);
        if (characteristic == null) {
            n("Rx charateristic not found!");
            f("com.nordicsemi.nrfUART.DEVICE_DOES_NOT_SUPPORT_UART");
            return;
        }
        characteristic.setValue(bArr);
        boolean zWriteCharacteristic = this.i.writeCharacteristic(characteristic);
        Log.d(f930a, "write TXchar - status=" + zWriteCharacteristic);
    }

    @Override // android.app.Service
    public IBinder onBind(Intent intent) {
        return this.p;
    }

    @Override // android.app.Service
    public boolean onUnbind(Intent intent) {
        h();
        return super.onUnbind(intent);
    }
}