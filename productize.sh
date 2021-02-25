#!/bin/bash -e

GH_BOM_BRANCH="7.4.x"
GH_PROD_BRANCH="$GH_BOM_BRANCH-devel"
GH_PROD_VERSION=$(curl -s https://raw.githubusercontent.com/redhat-developer/redhat-sso-boms/$GH_BOM_BRANCH/pom.xml | grep -m1 "<version>" | sed 's/<[^>]*>//g' | tr -d ' ')
KEYCLOAK_VERSION=$(curl -s https://raw.githubusercontent.com/redhat-developer/redhat-sso-boms/$GH_BOM_BRANCH/pom.xml | grep -m1 "<version.keycloak>" | sed 's/<[^>]*>//g' | tr -d ' ')

echo $GH_PROD_VERSION
echo $KEYCLOAK_VERSION

if [ "$GH_USER_NAME" != "" ] && [ "$GH_USER_EMAIL" != "" ] && [ "$GH_TOKEN" != "" ] && [ "$GH_REF" != "" ]; then
    DRY_RUN="false"
else
    DRY_RUN="true"
fi

if [ "$DRY_RUN" == "false" ]; then
	git config user.name "${GH_USER_NAME}"
	git config user.email "{GH_USER_EMAIL}"
fi

if [ "$DRY_RUN" == "true" ]; then
    if ( git branch | grep 'prod_staging' &>/dev/null ); then
        echo "prod_staging branch already exists, please delete and re-run"
        exit 1
    fi
fi

# Rename Keycloak to Red Hat SSO
find . -type f \( -name "*README*" -o -name "*getting-started*" -o -name "*test-development*" \) -exec sed -i 's@<span>Keycloak</span>@Red Hat SSO@g' {} +
# Rename repository links
find . -type f \( -name "*README*" -o -name "*getting-started*" -o -name "*test-development*" \) -exec sed -i 's@keycloak/keycloak-quickstarts@redhat-developer/redhat-sso-quickstarts@g' {} +
# Rename WildFly to JBoss EAP
find . -type f \( -name "*README*" -o -name "*getting-started*" -o -name "*test-development*" \) -exec  sed -i 's@<span>WildFly 10</span>@JBoss EAP 7.1.0@g' {} +
find . -type f \( -name "*README*" -o -name "*getting-started*" -o -name "*test-development*" \) -exec  sed -i 's@<span>WildFly</span>@JBoss EAP@g' {} +
# Rename values in tests
find ./*/src/test/java -type f -name "*Test*" -exec  sed -i 's@Keycloak Account Management@RH-SSO Account Management@g' {} +

# Rename env
find . -type f \( -name "*README*" -o -name "*getting-started*" -o -name "*test-development*" \) -exec  sed -i 's@<span>KEYCLOAK_HOME</span>@RHSSO_HOME@g' {} +
find . -type f \( -name "*README*" -o -name "*getting-started*" -o -name "*test-development*" \) -exec  sed -i 's@<span>WILDFLY_HOME</span>@EAP_HOME@g' {} +

# Rename commands
find . -type f \( -name "*README*" -o -name "*getting-started*" -o -name "*test-development*" \) -exec  sed -i 's@KEYCLOAK_HOME/bin@RHSSO_HOME/bin@g' {} +
find . -type f \( -name "*README*" -o -name "*getting-started*" -o -name "*test-development*" \) -exec  sed -i 's@KEYCLOAK_HOME\\bin@RHSSO_HOME\\bin@g' {} +
find . -type f \( -name "*README*" -o -name "*getting-started*" -o -name "*test-development*" \) -exec  sed -i 's@WILDFLY_HOME/bin@EAP_HOME/bin@g' {} +
find . -type f \( -name "*README*" -o -name "*getting-started*" -o -name "*test-development*" \) -exec  sed -i 's@WILDFLY_HOME\\bin@EAP_HOME\\bin@g' {} +

# Remove JBoss Repo
sed -i '/<repositories>/,/<\/repositories>/ d' pom.xml

# Add RHSSO Repo
sed -i '/<\/modules>/{ 
    a \    </modules>
    a \ 
    r scripts/ssorepo.txt
    d 
}' pom.xml

# Update version to productized versions
find . -type f -name "*pom.xml*" -exec sed -i "s/<version>.*SNAPSHOT/<version>$GH_PROD_VERSION/g" {} + 
find . -type f -name "*pom.xml*" -exec sed -i "s@<version.keycloak>.*</version.keycloak>@<version.keycloak>$KEYCLOAK_VERSION</version.keycloak>@g" {} + 

# Switch to productized artifacts
new_version='${project.version}'

find . -type f -name "*pom.xml*" -exec sed -i '/<dependency>/ {
    :start
    N
    /<\/dependency>$/!b start
    /<groupId>org.keycloak.bom<\/groupId>/ {
        s/\(<version>\).*\(<\/version>\)/\1'"$new_version"'\2/
    }
}' {} +
find . -type f -name "*pom.xml*" -exec sed -i 's@org.keycloak.bom@com.redhat.bom.rh-sso@g' {} + 
find . -type f -name "*pom.xml*" -exec sed -i 's@keycloak-adapter-bom@rh-sso-adapter-bom@g' {} + 
find . -type f -name "*pom.xml*" -exec sed -i 's@keycloak-spi-bom@rh-sso-spi-bom@g' {} + 
find . -type f -name "*pom.xml*" -exec sed -i 's@keycloak-misc-bom@rh-sso-misc-bom@g' {} + 

# Rename names in POMs
find . -type f -name "*pom.xml*" -exec sed -i 's@<name>Keycloak Quickstart@<name>Red Hat SSO Quickstart@g' {} +


git checkout -b prod_staging
git checkout action-token-authenticator/pom.xml
git checkout action-token-required-action/pom.xml 
git checkout app-springboot/pom.xml
git checkout app-springboot/README.md
git checkout event-listener-sysout/pom.xml
git checkout event-store-mem/pom.xml 
git rm -r -f action-token-authenticator
git rm -r -f action-token-required-action
git rm -r -f app-springboot 
git rm -r -f kubernetes-examples
git rm -r -f openshift-examples
git rm -r -f event-listener-sysout
git rm -r -f event-store-mem
git status

git commit . -m "Converted to RH-SSO QuickStarts"

if [ "$DRY_RUN" == "false" ]; then
    git push --force "https://${GH_TOKEN}@${GH_REF}" prod_staging:$GH_PROD_BRANCH
else
    echo ""
    echo "Dry run, not committing"
    echo ""
fi
