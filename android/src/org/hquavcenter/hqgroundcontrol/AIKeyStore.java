package org.hquavcenter.hqgroundcontrol;
import android.content.Context;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;
import android.util.Base64;
import java.nio.charset.StandardCharsets;
import java.security.KeyStore;
import java.util.Arrays;
import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;

/** Stores only AES-GCM ciphertext in the app's private preferences. */
public final class AIKeyStore {
    private static final String PREFS = "hq_ai_credentials";
    private AIKeyStore() {}
    private static SecretKey key(String alias, boolean create) throws Exception {
        KeyStore store = KeyStore.getInstance("AndroidKeyStore");
        store.load(null);
        if (!store.containsAlias(alias)) {
            if (!create) return null;
            KeyGenerator generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore");
            generator.init(new KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT | KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setRandomizedEncryptionRequired(true).build());
            return generator.generateKey();
        }
        return (SecretKey) store.getKey(alias, null);
    }
    public static String read(Context context, String alias) {
        try {
            String value = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(alias, "");
            if (value.isEmpty()) return "";
            byte[] payload = Base64.decode(value, Base64.NO_WRAP);
            if (payload.length < 29) return "";
            SecretKey secret = key(alias, false);
            if (secret == null) return "";
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.DECRYPT_MODE, secret, new GCMParameterSpec(128, Arrays.copyOfRange(payload, 0, 12)));
            return new String(cipher.doFinal(Arrays.copyOfRange(payload, 12, payload.length)), StandardCharsets.UTF_8);
        } catch (Exception error) { return ""; }
    }
    public static boolean write(Context context, String alias, String value) {
        try {
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.ENCRYPT_MODE, key(alias, true));
            byte[] encrypted = cipher.doFinal(value.getBytes(StandardCharsets.UTF_8));
            byte[] iv = cipher.getIV();
            if (iv.length != 12) return false;
            byte[] payload = new byte[iv.length + encrypted.length];
            System.arraycopy(iv, 0, payload, 0, iv.length);
            System.arraycopy(encrypted, 0, payload, iv.length, encrypted.length);
            return context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putString(alias, Base64.encodeToString(payload, Base64.NO_WRAP)).commit();
        } catch (Exception error) { return false; }
    }
    public static boolean remove(Context context, String alias) {
        try {
            if (!context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().remove(alias).commit()) return false;
            KeyStore store = KeyStore.getInstance("AndroidKeyStore");
            store.load(null);
            if (store.containsAlias(alias)) store.deleteEntry(alias);
            return true;
        } catch (Exception error) { return false; }
    }
}
