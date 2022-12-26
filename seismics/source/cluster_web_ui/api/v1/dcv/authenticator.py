import config
from cryptography.fernet import Fernet
from flask_restful import Resource, reqparse
from flask import request
import logging
from flask import Response
import base64
import ast
import errors
from models import db, LinuxDCVSessions, WindowsDCVSessions

logger = logging.getLogger("api")


def decrypt(encrypted_text):
    try:
        key = config.Config.DCV_TOKEN_SYMMETRIC_KEY
        cipher_suite = Fernet(key)
        decrypted_text = cipher_suite.decrypt(encrypted_text)
        return decrypted_text.decode()
    except Exception as err:
        logger.error("Unable to decrypt {} due to {}".format(encrypted_text,err))
        return False


class DcvAuthenticator(Resource):
    def post(self):
        """
        Authenticate DCV sessions
        ---
        tags:
          - System
        responses:
          200:
            description: Pair of user/token is valid
          401:
            description: Invalid user/token pair
        """
        logger.info("DCV Auth")
        parser = reqparse.RequestParser()
        parser.add_argument('sessionId', type=str, location='form')
        parser.add_argument('authenticationToken', type=str, location='form')
        parser.add_argument('clientAddress', type=str, location='form')
        args = parser.parse_args()
        remote_addr = request.remote_addr
        if args["sessionId"] is None or args['authenticationToken'] is None or args["clientAddress"] is None:
            return errors.all_errors('CLIENT_MISSING_PARAMETER', "sessionId (str), clientAddress (str) and authenticationToken (str) are required.")
        session_id = args["sessionId"]
        authentication_token = args['authenticationToken']
        client_address = args["clientAddress"].split(":")[0]  # keep only ip, remove port
        error = False
        user = False
        required_params = ["system", "session_user", "session_token", "session_instance_id"]
        session_info = {}
        logger.info("Detected {} and remote_addr {}".format(args, remote_addr))

        try:
            decoded_token = decrypt(base64.b64decode(authentication_token))
            if decoded_token is False:
                logger.error("Unable to decrypt the authentication token. It was probably generated by a different Fernet key")
                error = True
            else:
                decoded_token = ast.literal_eval(decoded_token)
        except Exception as err:
            logger.error("Unable to base64 decode the authentication token")
            error = True

        if error is False:
            for param in required_params:
                if param not in decoded_token.keys():
                    logger.error("Unable to find {} in {}".format(decoded_token, decoded_token))
                    error = True
                else:
                    session_info[param] = decoded_token[param]
        if error is False:
            if session_info["system"].lower() == "windows":
                validate_session = WindowsDCVSessions.query.filter_by(user=session_info["session_user"],
                                                                      session_host_private_ip=remote_addr,
                                                                      session_token=session_info["session_token"],
                                                                      session_instance_id=session_info["session_instance_id"],
                                                                      is_active=True).first()

            else:
                validate_session = LinuxDCVSessions.query.filter_by(user=session_info["session_user"],
                                                                    session_host_private_ip=remote_addr,
                                                                    session_token=session_info["session_token"],
                                                                    session_instance_id=session_info["session_instance_id"],
                                                                    is_active=True).first()
            if validate_session:
                user = session_info["session_user"]
            else:
                error = True

        if error is False and user is not False:
            xml_response = '<auth result="yes"><username>' + user +'</username></auth>'
            status = 200
            logger.info("Successfully authenticated session")
        else:
            xml_response = '<auth result="no"/>'
            status = 401
            logger.error("Unable to authenticate this DCV session. Make sure remote_addr point to the private IP address of your DCV manager (verify your proxy settings).")

        return Response(xml_response, status=status, mimetype='text/xml')
