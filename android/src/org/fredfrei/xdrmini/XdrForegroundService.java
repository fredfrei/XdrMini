package org.fredfrei.xdrmini;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ServiceInfo;
import android.os.Build;
import android.os.IBinder;

public class XdrForegroundService extends Service {
    private static final String CHANNEL_ID = "xdrmini_radio_connection";
    private static final int NOTIFICATION_ID = 6686;

    public static void start(Context context) {
        Intent intent = new Intent(context, XdrForegroundService.class);

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(intent);
        } else {
            context.startService(intent);
        }
    }

    public static void stop(Context context) {
        Intent intent = new Intent(context, XdrForegroundService.class);
        context.stopService(intent);
    }

    @Override
    public void onCreate() {
        super.onCreate();
        createNotificationChannel();

        Notification notification = buildNotification();

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE
            );
        } else {
            startForeground(NOTIFICATION_ID, notification);
        }
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        // Der Service hält die laufende App im Vordergrund.
        // Wird der gesamte Prozess beendet, wird er nicht ohne die Qt-App
        // allein neu gestartet.
        return START_NOT_STICKY;
    }

    @Override
    public void onDestroy() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE);
        } else {
            stopForeground(true);
        }

        super.onDestroy();
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O)
            return;

        NotificationChannel channel = new NotificationChannel(
            CHANNEL_ID,
            "XdrMini Radioverbindung",
            NotificationManager.IMPORTANCE_LOW
        );

        channel.setDescription(
            "Hält die Verbindung zum TEF6686-Radio im Hintergrund aktiv."
        );

        NotificationManager manager =
            (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);

        if (manager != null)
            manager.createNotificationChannel(channel);
    }

    private Notification buildNotification() {
        Intent launchIntent =
            getPackageManager().getLaunchIntentForPackage(getPackageName());

        PendingIntent pendingIntent = null;

        if (launchIntent != null) {
            launchIntent.addFlags(
                Intent.FLAG_ACTIVITY_SINGLE_TOP |
                Intent.FLAG_ACTIVITY_CLEAR_TOP
            );

            int pendingFlags = PendingIntent.FLAG_UPDATE_CURRENT;

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
                pendingFlags |= PendingIntent.FLAG_IMMUTABLE;

            pendingIntent = PendingIntent.getActivity(
                this,
                0,
                launchIntent,
                pendingFlags
            );
        }

        int iconId = getResources().getIdentifier(
            "ic_xdrmini_service",
            "drawable",
            getPackageName()
        );

        if (iconId == 0)
            iconId = android.R.drawable.stat_notify_sync;

        Notification.Builder builder;

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            builder = new Notification.Builder(this, CHANNEL_ID);
        else
            builder = new Notification.Builder(this);

        builder
            .setSmallIcon(iconId)
            .setContentTitle("XdrMini")
            .setContentText("Hintergrunddienst für die Radioverbindung aktiv")
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(Notification.CATEGORY_SERVICE)
            .setVisibility(Notification.VISIBILITY_PUBLIC);

        if (pendingIntent != null)
            builder.setContentIntent(pendingIntent);

        return builder.build();
    }
}
