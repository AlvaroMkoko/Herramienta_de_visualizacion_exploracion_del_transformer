"""Configuración TLS efímera para el transporte del aula local."""

from __future__ import annotations

import ipaddress
import string
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.x509.oid import ExtendedKeyUsageOID, NameOID
from PySide6.QtCore import QCryptographicHash
from PySide6.QtNetwork import QSsl, QSslCertificate, QSslConfiguration, QSslKey, QSslSocket


#: El alumno confía en la huella fijada, no en la fecha (``cliente_lan``
#: ignora los errores de un certificado cuya huella coincide). El certificado
#: vive tanto como la clase, que puede durar varios semestres.
VIGENCIA_CERTIFICADO = timedelta(days=3650)


@dataclass(frozen=True)
class CredencialesTls:
    configuracion: QSslConfiguration
    huella_sha256: str
    certificado_pem: bytes = b""
    clave_pem: bytes = b""


def crear_credenciales_servidor(
    certificado_pem: bytes | None = None, clave_pem: bytes | None = None
) -> CredencialesTls:
    """Configuración TLS para Qt con el certificado dado o, sin él, uno nuevo.

    Un certificado guardado que no se puede cargar se reemplaza por uno nuevo:
    los alumnos tendrán que volver a unirse por dirección, pero la clase abre.
    """
    if certificado_pem and clave_pem:
        try:
            return _configurar(certificado_pem, clave_pem)
        except (ValueError, RuntimeError):
            pass
    clave = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    nombre = x509.Name(
        [x509.NameAttribute(NameOID.COMMON_NAME, "Transformer Visualizer Aula")]
    )
    ahora = datetime.now(timezone.utc)
    certificado = (
        x509.CertificateBuilder()
        .subject_name(nombre)
        .issuer_name(nombre)
        .public_key(clave.public_key())
        .serial_number(x509.random_serial_number())
        .not_valid_before(ahora - timedelta(minutes=1))
        .not_valid_after(ahora + VIGENCIA_CERTIFICADO)
        .add_extension(x509.BasicConstraints(ca=False, path_length=None), critical=True)
        .add_extension(
            x509.ExtendedKeyUsage([ExtendedKeyUsageOID.SERVER_AUTH]), critical=False
        )
        .add_extension(
            x509.SubjectAlternativeName(
                [
                    x509.DNSName("localhost"),
                    x509.IPAddress(ipaddress.ip_address("127.0.0.1")),
                ]
            ),
            critical=False,
        )
        .sign(clave, hashes.SHA256())
    )

    return _configurar(
        certificado.public_bytes(serialization.Encoding.PEM),
        clave.private_bytes(
            serialization.Encoding.PEM,
            serialization.PrivateFormat.TraditionalOpenSSL,
            serialization.NoEncryption(),
        ),
    )


def _configurar(certificado_pem: bytes, clave_pem: bytes) -> CredencialesTls:
    huella = x509.load_pem_x509_certificate(certificado_pem).fingerprint(hashes.SHA256()).hex()
    certificado_qt = QSslCertificate(certificado_pem, QSsl.EncodingFormat.Pem)
    clave_qt = QSslKey(
        clave_pem,
        QSsl.KeyAlgorithm.Rsa,
        QSsl.EncodingFormat.Pem,
        QSsl.KeyType.PrivateKey,
    )
    if certificado_qt.isNull() or clave_qt.isNull():
        raise RuntimeError("Qt no pudo cargar las credenciales TLS del aula.")

    configuracion = QSslConfiguration.defaultConfiguration()
    configuracion.setLocalCertificate(certificado_qt)
    configuracion.setPrivateKey(clave_qt)
    configuracion.setProtocol(QSsl.SslProtocol.TlsV1_2OrLater)
    configuracion.setPeerVerifyMode(QSslSocket.PeerVerifyMode.VerifyNone)
    return CredencialesTls(
        configuracion=configuracion,
        huella_sha256=huella,
        certificado_pem=certificado_pem,
        clave_pem=clave_pem,
    )


def huella_certificado(certificado: QSslCertificate) -> str:
    """Devuelve la huella SHA-256 hexadecimal de un certificado Qt."""
    if certificado.isNull():
        return ""
    resumen = certificado.digest(QCryptographicHash.Algorithm.Sha256).toHex()
    return bytes(resumen).decode("ascii").lower()


def normalizar_huella(valor: object) -> str:
    """Acepta únicamente una huella SHA-256 hexadecimal completa."""
    huella = str(valor or "").strip().lower()
    if len(huella) != 64 or any(caracter not in string.hexdigits for caracter in huella):
        return ""
    return huella
