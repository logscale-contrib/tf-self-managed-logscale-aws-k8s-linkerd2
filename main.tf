resource "tls_private_key" "trustanchor_key" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_private_key" "issuer_key" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_cert_request" "issuer_req" {
  private_key_pem = tls_private_key.issuer_key.private_key_pem

  subject {
    common_name = "identity.linkerd.cluster.local"
  }
}

resource "tls_locally_signed_cert" "issuer_cert" {
  cert_request_pem      = tls_cert_request.issuer_req.cert_request_pem
  ca_private_key_pem    = tls_private_key.trustanchor_key.private_key_pem
  ca_cert_pem           = tls_self_signed_cert.trustanchor_cert.cert_pem
  validity_period_hours = 8760
  is_ca_certificate     = true

  allowed_uses = [
    "crl_signing",
    "cert_signing",
    "server_auth",
    "client_auth"
  ]
}

resource "tls_self_signed_cert" "trustanchor_cert" {
  private_key_pem       = tls_private_key.trustanchor_key.private_key_pem
  validity_period_hours = 876000
  is_ca_certificate     = true

  subject {
    common_name = "identity.linkerd.cluster.local"
  }

  allowed_uses = [
    "crl_signing",
    "cert_signing",
    "server_auth",
    "client_auth"
  ]
}
resource "helm_release" "linkerd-crds" {
  name             = "linkerd-crds"
  namespace        = "linkerd"
  repository       = "https://helm.linkerd.io/stable"
  version          = "1.4.0"
  chart            = "linkerd-crds"
  timeout          = 600
  create_namespace = true

}

resource "helm_release" "linkerd" {
  depends_on = [
    helm_release.linkerd-crds
  ]
  name       = "linkerd"
  namespace  = "linkerd"
  repository = "https://helm.linkerd.io/stable"
  version    = "1.9.3"
  chart      = "linkerd-control-plane"
  timeout    = 600

  create_namespace = false
  values = [<<EOF
# -- Create PodDisruptionBudget resources for each control plane workload
enablePodDisruptionBudget: true

# -- Specify a deployment strategy for each control plane workload
deploymentStrategy:
  rollingUpdate:
    maxUnavailable: 1
    maxSurge: 25%

# -- add PodAntiAffinity to each control plane workload
enablePodAntiAffinity: true

# nodeSelector:
#   beta.humio.com/pool: system

# proxy configuration
proxy:
  resources:
    cpu:
      request: 100m
    memory:
      limit: 250Mi
      request: 20Mi

# controller configuration
controllerReplicas: 2
controllerResources: &controller_resources
  cpu: &controller_resources_cpu
    limit: ""
    request: 100m
  memory:
    limit: 250Mi
    request: 50Mi
destinationResources: *controller_resources

# identity configuration
identityResources:
  cpu: *controller_resources_cpu
  memory:
    limit: 250Mi
    request: 10Mi

# heartbeat configuration
heartbeatResources: *controller_resources

# proxy injector configuration
proxyInjectorResources: *controller_resources
webhookFailurePolicy: Fail

# service profile validator configuration
spValidatorResources: *controller_resources

    EOF
  ]


  set {
    name  = "identityTrustAnchorsPEM"
    value = tls_self_signed_cert.trustanchor_cert.cert_pem
  }

  set {
    name  = "identity.issuer.crtExpiry"
    value = tls_locally_signed_cert.issuer_cert.validity_end_time
  }

  set {
    name  = "identity.issuer.tls.crtPEM"
    value = tls_locally_signed_cert.issuer_cert.cert_pem
  }

  set {
    name  = "identity.issuer.tls.keyPEM"
    value = tls_private_key.issuer_key.private_key_pem
  }
  set {
    name  = "cniEnabled"
    value = "true"
  }
}


resource "kubernetes_labels" "kube_system" {
  api_version = "v1"
  kind        = "Namespace"
  metadata {
    name = "kube-system"
  }
  labels = {
    "config.linkerd.io/admission-webhooks" = "disabled"
  }
}

resource "helm_release" "kube-system" {
  depends_on = [
    helm_release.linkerd-crds,
    kubernetes_labels.kube_system
  ]

  name       = "linkerd-cni"
  namespace  = "linkerd"
  repository = "https://helm.linkerd.io/stable"
  version    = "30.3.3"
  chart      = "linkerd2-cni"
  # create_namespace = 
  #   values = [<<EOF
  # priorityClassName: system-node-critical
  #     EOF
  #   ]
}


resource "helm_release" "viz" {
  depends_on = [
    helm_release.linkerd-crds,
    kubernetes_labels.kube_system
  ]

  name       = "linkerd-viz"
  namespace  = "linkerd"
  repository = "https://helm.linkerd.io/stable"
  version    = "30.3.3"
  chart      = "linkerd2-viz"
  # create_namespace = 
  #   values = [<<EOF
  # priorityClassName: system-node-critical
  #     EOF
  #   ]
}
