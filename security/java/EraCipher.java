import com.jaspersoft.jasperserver.api.common.crypto.CipherI;

public class EraCipher implements CipherI {
	@Override
	public String encrypt(String plainText) {
		return plainText;
	}

	@Override
	public String decrypt(String plainText) {
		return plainText;
	}
}
