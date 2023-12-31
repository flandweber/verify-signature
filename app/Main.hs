{-# LANGUAGE OverloadedStrings #-}

module Main where
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as C
import qualified Extra
import qualified Crypto.PubKey.Ed25519 as Ed25519
import Crypto.Error
import qualified Data.ByteString.Base64 as Base64
import qualified Data.ByteString.Base16 as Base16
import Crypto.Hash

sha512 :: C.ByteString -> String
sha512 bs = show (hash bs :: Digest SHA512)

intArrayToByteString :: [Int] -> C.ByteString
intArrayToByteString = BS.pack . map fromIntegral

hexStringToIntList :: String -> Either String [Int]
hexStringToIntList hexStr = do
    decoded <- Base16.decode (C.pack hexStr)
    return $ map fromIntegral (BS.unpack decoded)

unarmorSignature :: C.ByteString -> C.ByteString
unarmorSignature = removeHeader . removeFooter . removeLinebreaks
        where
                header = "-----BEGIN SSH SIGNATURE-----"
                footer = "-----END SSH SIGNATURE-----"
                removeHeader = C.drop (C.length header) . snd . C.breakSubstring header
                removeFooter = fst . C.breakSubstring footer
                removeLinebreaks = C.filter (/= '\n')

main :: IO ()
main = do 
        message <- BS.readFile "data/message.txt"
        let hash = Extra.fromRight' $ hexStringToIntList $ sha512 message
        let intSignedText = [ 83, 83, 72, 83, 73, 71, 0, 0, 0, 4 -- SSHSIG magic header
                    , 102, 105, 108, 101 -- namespace ("file")
                    , 0, 0, 0, 0, 0, 0, 0, 6 -- reserved
                    , 115, 104, 97, 53, 49, 50, 0, 0, 0, 64 -- hash alg (sha512)
                    ] ++ hash
        print (intArrayToByteString intSignedText)

        signatureWrapped <- BS.readFile "data/message.txt.sig"
        let signatureDecoded = Extra.fromRight' $ Base64.decode $ unarmorSignature signatureWrapped
        let signatureBS = BS.takeEnd 64 signatureDecoded
        signature <- throwCryptoErrorIO $ Ed25519.signature signatureBS
        print signature

        keyfileContent <- BS.readFile "data/authorized_signers"
        let _:_:key:_ = C.words keyfileContent
        let keyDecoded = Extra.fromRight' $ Base64.decode key
        let Just keyBS = C.stripPrefix "\NUL\NUL\NUL\vssh-ed25519\NUL\NUL\NUL " keyDecoded
        key <- throwCryptoErrorIO $ Ed25519.publicKey keyBS
        print key

        let result = Ed25519.verify key (intArrayToByteString intSignedText) signature
        print result
        
