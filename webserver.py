import sys
import os
from flask import Flask, request, jsonify
from pathlib import Path
import jsonpatch
import base64


admission_controller = Flask(__name__)
admission_controller.debug =  os.getenv("DEBUG", 'True').lower() in ('true', '1')
# This is the minimum number of replica, fetched from the env variables
MINIMUM_REPLICA_COUNT = os.getenv("MINIMUM_REPLICA_COUNT", 3)

@admission_controller.route("/mutate/deployments/replicas", methods=["POST"])
def pod_webhook_mutate():
    request_info = request.get_json()
    requested_replicas = request_info['request']['object']['spec']['replicas']
    namespace = request_info['request']['object']['metadata']['namespace']
    admission_controller.logger.debug(f"namespace: {namespace} requested replicas: {requested_replicas}")
    if requested_replicas < MINIMUM_REPLICA_COUNT:
        admission_controller.logger.debug(f"requested replica count is lesser than Minimum replicas{MINIMUM_REPLICA_COUNT} required in this namespace, patching it")
        json_patch=jsonpatch.JsonPatch(
                [{"op": "add", "path": "/spec/replicas", "value": 3}]
            )
        base64_patch = base64.b64encode(json_patch.to_string().encode("utf-8")).decode(
            "utf-8"
        )
        return jsonify(
        {
            "apiVersion": request_info.get("apiVersion"),
            "kind": request_info.get("kind"),
            "response": {
                "uid": request_info["request"].get("uid"),
                "allowed": True,
                "status": {"message": "Adding allow label"},
                "patchType": "JSONPatch",
                "patch": base64_patch
            }
        }
    )
    admission_controller.logger.debug(f"requested replica count satisfies Minimum replicas{MINIMUM_REPLICA_COUNT} required in this namespace, skipping it")
    return jsonify(
        {
            "apiVersion": request_info.get("apiVersion"),
            "kind": request_info.get("kind"),
            "response": {
                "uid": request_info["request"].get("uid"),
                "allowed": True
            }
        }
    )



if __name__ == "__main__":
    admission_controller.run(
        host='0.0.0.0')

