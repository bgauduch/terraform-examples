#!/usr/bin/env bash
# Sweeper : nettoie les buckets de test orphelins (laissés par un `terraform test`
# interrompu avant son auto-destroy). Cible les ressources portant le tag de suite.
# Source de vérité du tag : providers.tf (default_tags tftest-suite).
#
# Usage:
#   ./sweep.sh           # liste les buckets taggés (dry-run)
#   ./sweep.sh --force   # vide puis supprime chaque bucket taggé
#
# Requiert AWS_PROFILE (ex: sandbox). Alternative outillée : aws-nuke / awsweeper
# filtrés sur le même tag.
set -euo pipefail

TAG_KEY="tftest-suite"
TAG_VALUE="terraform-module-testing"
REGION="${AWS_REGION:-eu-west-1}"
FORCE="${1:-}"

mapfile -t ARNS < <(aws resourcegroupstaggingapi get-resources \
  --region "$REGION" \
  --tag-filters "Key=${TAG_KEY},Values=${TAG_VALUE}" \
  --resource-type-filters "s3" \
  --query 'ResourceTagMappingList[].ResourceARN' --output text | tr '\t' '\n')

if [ "${#ARNS[@]}" -eq 0 ] || [ -z "${ARNS[0]:-}" ]; then
  echo "Aucun bucket taggé ${TAG_KEY}=${TAG_VALUE}."
  exit 0
fi

echo "Buckets taggés trouvés :"
printf '  %s\n' "${ARNS[@]}"

if [ "$FORCE" != "--force" ]; then
  echo "Dry-run. Relancer avec --force pour vider + supprimer."
  exit 0
fi

for arn in "${ARNS[@]}"; do
  bucket="${arn##*:::}"
  echo "Suppression de ${bucket} ..."
  aws s3 rm "s3://${bucket}" --recursive >/dev/null 2>&1 || true
  aws s3api delete-bucket --bucket "${bucket}" --region "$REGION"
done
echo "Nettoyage terminé."
