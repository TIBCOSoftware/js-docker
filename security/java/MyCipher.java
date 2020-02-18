import com.jaspersoft.jasperserver.api.common.crypto.CipherI;

import javax.crypto.Cipher;
import javax.crypto.spec.IvParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import java.util.Base64;

public class MyCipher implements CipherI {

    private static String CIPHER_NAME = "AES/CBC/PKCS5PADDING";
    private static int CIPHER_KEY_LEN = 16; //128 bits
    private static String CIPHER_KEY = "Bhng90UQrNs33Dlql2YnyETlTesc0C3g";
    private static String CIPHER_VEKTOR = "abcdef9876543210";

    private static String fixKey(String key) {
        if (key.length() < MyCipher.CIPHER_KEY_LEN) {
            int numPad = MyCipher.CIPHER_KEY_LEN - key.length();

            for (int i = 0; i < numPad; i++) {
                key += "0"; //0 pad to len 16 bytes
            }
            return key;
        }
        if (key.length() > MyCipher.CIPHER_KEY_LEN) {
            return key.substring(0, MyCipher.CIPHER_KEY_LEN); //truncate to 16 bytes
        }
        return key;
    }

    @Override
	public String encrypt(String plainText) {
        try {
            IvParameterSpec ivSpec = new IvParameterSpec(MyCipher.CIPHER_VEKTOR.getBytes("UTF-8"));
            SecretKeySpec secretKey = new SecretKeySpec(fixKey(MyCipher.CIPHER_KEY).getBytes("UTF-8"), "AES");

            Cipher cipher = Cipher.getInstance(MyCipher.CIPHER_NAME);
            cipher.init(Cipher.ENCRYPT_MODE, secretKey, ivSpec);

            byte[] encryptedData = cipher.doFinal((plainText.getBytes()));

            String encryptedDataInBase64 = Base64.getEncoder().encodeToString(encryptedData);
            String ivInBase64 = Base64.getEncoder().encodeToString(MyCipher.CIPHER_VEKTOR.getBytes("UTF-8"));

            return encryptedDataInBase64 + ":" + ivInBase64;
        } catch (Exception ex) {
          throw new RuntimeException(ex);
        }
	}

    @Override
	public String decrypt(String plainText) {
        try {
          String[] parts = plainText.split(":");

          IvParameterSpec iv = new IvParameterSpec(Base64.getDecoder().decode(parts[1]));
          SecretKeySpec secretKey = new SecretKeySpec(fixKey(MyCipher.CIPHER_KEY).getBytes("UTF-8"), "AES");

          Cipher cipher = Cipher.getInstance(MyCipher.CIPHER_NAME);
          cipher.init(Cipher.DECRYPT_MODE, secretKey, iv);

          byte[] decodedEncryptedData = Base64.getDecoder().decode(parts[0]);
          byte[] original = cipher.doFinal(decodedEncryptedData);

          return new String(original);
        } catch (Exception ex) {
          throw new RuntimeException(ex);
        }
	}

	public static void main(String args[]) {
		String orginalString="u=mehulkatara";

		MyCipher obj = new MyCipher();
		String encryptString = obj.encrypt(orginalString);
		String decryptString = obj.decrypt(encryptString);

		System.out.println(orginalString);
		System.out.println(encryptString);
		System.out.println(decryptString);
	}
}
