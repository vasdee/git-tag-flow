# Git Tag Flow 

Git Tag Flow is an alternate, convention based workflow to gitflow and trunk based work flows. 
It combines the best (lightest) features of both, and provides and opininionated, yet simple, deployment and release
strategy via git tags and the principle of GitOps. 


## Why another git work flow?

Git flow is heavy and even considered legacy by [some] (https://www.atlassian.com/git/tutorials/comparing-workflows/gitflow-workflow). 
Heavy in that it requires maintenance of long lived branches and requires strict conventions when performing releases via release branches.

Trunk based develops suggests that your architecture should change in order to facilitate being able to deploy potentially "broken" functionality into production.

Git Tag Flow takes the simplicity of trunk and applies *some* of the wisdom from gitflow, enabling GitOps via tags and enabling tracibility of actions back to atomic commits.
The principle is simple, you should always be able to trace back exactly what you deployed to production, within your git repository. This is not only common sense, but makes
replicating production issues locally a less painful process.

## When should I use git tag flow?

Git tag flow is ideal for microservices, or solutions where the artifacts produced are 1-1 with the repositories. For example, if you maintain
several repositories that each build a single docker image and maintain a deployment via another git repository, say via a `docker-compose.yml` file, then git-tag-flow is ideal. 

It is not limited to container solutions....

Consider a classic web application with a RESTful backend, a Single Page Application and 
infrastructure-as-code that deploys to a cloud environment, each hosted in their own Git repository. Using git-tag-flow, the backend and frontend repositories will both 
produce their own distinct artifacts, the infrastructure-as-code deployment will deploy the artifacts. 

It can also work with mono-repos, however it comes with some caveats which are likely already accepted regardless of workflow.

## Conventions

### Branches

Single main (trunk) line of development. This is the only permanent branch, and should have controlled access.

short-lived branches that are used for working on various code types. These are left up to the discretion of the user, but some typical examples would be 
`feature/some-feature`, `bugfix/JIRA-1234` or `chore/update-changelog`

For deployment repositories, an extra shortlived branch is required that is used to deploy your solution from, typically this is called `staging/`

### Tags

Tags are used to trigger events within git-tag-flow. But it is up to you to decide what actions are performed when a tag is pushed to a repository. 

**Note** *Because of this requirement, a CICD solution is required that can be triggered from git tags*

By convention, the base tag recommended is `release/`, this allows your build pipeline to be able to detect tags and allows you to use whatever 
follows the `release/` stubb to control the flow of build events. 

For example, given a frontend SPA application. Tagging the main branch with `release/1.0.0` might cause your build pipeline to create a zip file artifact
called `spa-1.0.0.zip` or perhaps build and push a docker image called `spa:1.0.0` - it is up to you on how to react to these events, however command scenarios are listed below.

For a deployment repository, things often get slightly more complicated due to the nature of maintaining multiple environments eg  dev, test, qa & prod. A simple solution to this 
problem is to extend the tag to include an environment. 

For example, `release/dev/1.0.0` placed on the deployment repository would cause your build pipeline to deploy version `1.0.0` to the `dev` environment, assuming your pipeline
is able to parse the tag values. This deployment repository also assumes that a manifest exists that defines the correct version of the SPA and backend components, like a `docker-compose.yml`
file or VM cloud init script. 


### Restrictions on Tag placement

Tags should always trigger a pipeline, regardless of where they are placed within version control. The reason for this is that managing multiple releases is a very real thing and 
the reason the deployment repository specifies a `staging/` branch convention.

When managing multiple `staging/` branches, release tags can be placed on any commit and *ideally* a deployment will occur. 
When managing a single release, then the release tag can be placed on the main branch with the same effect. It is however, good 
practice to place all releases within a `staging/` branch so that pull requests (and pull request specific pipelines) can occur.

You might ask, "Why is `staging/` the defacto name for a what is essentially a release branch". Well, the answer is that naming your branches the same as a tag
can cause some confusion. For example, `git checkout release/1.0.0` - are we checking out a tag or branch here?? For this reason `staging/` is the branch name that 
is used to trigger a release, when the `release/` tag is applied.

## Interaction with changelogs

git-tag-flow doesn't believe in automatic generation of changelogs. Automatic generation of changelogs is not a deterministic action and changelogs
**should** be managed via the dev, and treated as a change to the code base in which it lives.

That being said, there is nothing to stop you generating a changelog during a build event.

## Scenarios 

### Simple Scenario

* branch
* update changelog
* code
* push
* review
* code && push
* rebase
* tag (optional)
* merge to master



### Deploying to environment via tag

For reference, this particular build pipeline extract is from Azure Devops.

```yaml
variables:
  - name: isMain
    value: $[eq(variables['Build.SourceBranch'], 'refs/heads/master')]
  - name: isReleaseTag
    value: $[startsWith(variables['Build.SourceBranch'], 'refs/tags/release/')]

trigger:
  tags:
    include:
      - release/*

steps:
  - script: |
        # removes the refs/tags/
        export GIT_TAG=${BUILD_SOURCEBRANCH:10} 
        export ENVIRONMENT=$(echo ${GIT_TAG} | cut --delimiter=/ -f2)
        export RELEASE_VERSION=$(echo ${GIT_TAG} | cut --delimiter=/ -f3)
        export DOCKER_REGISTRY_PASSWORD
        export DOCKER_REGISTRY_USERNAME
        export DOCKER_REGISTRY_FQDN
        make -e deploy
    env:
      DOCKER_REGISTRY_PASSWORD: $(REGISTRY_PASSWORD)
      DOCKER_REGISTRY_USERNAME: $(REGISTRY_USERNAME)
      DOCKER_REGISTRY_FQDN: $(REGISTRY_FQDN)
    displayName: Deploy...
    condition: eq(variables.isReleaseTag, true)
```

### Hot Fix

### Feature Flow 

### Managing multiple releases

### Container builds with latest and fixed version tags

Example of a general purpose build pipeline that can create a `latest` docker image or fix version
depending on the build condition. For reference, this particular build pipeline extract is from Azure Devops.

```yaml

variables:
  - name: isMain
    value: $[eq(variables['Build.SourceBranch'], 'refs/heads/master')]
  - name: isReleaseTag
    value: $[startsWith(variables['Build.SourceBranch'], 'refs/tags/release/')]

trigger:
  tags:
    include:
      - release/*

steps:
  - script: |
        export DOCKER_IMAGE_TAG=latest
        export DOCKER_REGISTRY_PASSWORD
        export DOCKER_REGISTRY_USERNAME
        export DOCKER_REGISTRY_FQDN
        make -e docker-build
        make -e docker-push
    displayName: Build and Push Latest Image
    condition: or(eq(variables.isMain, true), eq(variables.isReleaseTag, true))
    env:
      DOCKER_REGISTRY_FQDN: $(REGISTRY_FQDN)
      DOCKER_REGISTRY_PASSWORD: $(REGISTRY_PASSWORD)
      DOCKER_REGISTRY_USERNAME: $(REGISTRY_USERNAME)


  - script: |
        # 18 characters == refs/tags/release/
        export DOCKER_IMAGE_TAG=${BUILD_SOURCEBRANCH:18}
        export DOCKER_REGISTRY_PASSWORD
        export DOCKER_REGISTRY_USERNAME
        export DOCKER_REGISTRY_FQDN
        make -e docker-build
        make -e docker-push
    env:
      DOCKER_REGISTRY_PASSWORD: $(REGISTRY_PASSWORD)
      DOCKER_REGISTRY_USERNAME: $(REGISTRY_USERNAME)
      DOCKER_REGISTRY_FQDN: $(REGISTRY_FQDN)
    displayName: Build and Push Release Image
    condition: eq(variables.isReleaseTag, true)
```

### Mono Repos

Git-Tag-Flow can  work with mono-repos, however there are reasons why a mono repo
might not always be [a](https://fossa.com/blog/pros-cons-using-monorepos/) [good](https://alexey-soshin.medium.com/monorepo-is-a-bad-idea-5e587e848a07) [choice](https://semaphoreci.com/blog/what-is-monorepo).

Unlike with a multi-repo setup, in a mono-repo setup you can't deploy your artifacts via separate version numbers, as now your repository contains 
multiple projects and using git tags wouldn't be efficient. Instead, the release deployment is used to generate the artifacts and deploy the release
all in one.

For example, given the follwing simple mono-repo containing the a frontend, backend and deployment folder.

```
.git
project/
  /frontend/
  /backend/
  /deployment/
```

It is time for a new release to our test environment, so a dev creates a `staging/` branch to manage the deployments from, in this example
we'll use `staging/1.0.2`. A tag is then placed on this branch, called `release/test/1.0.2` and pushed to the remote.

It would be expected in this case that the CICD solution would create the frontend and backend artifacts, before the deployment procedure is called. This might 
result in two artifacts, `frontend-1.0.2.zip` and `backend-1.0.2.zip`, that is, they have inherited the version number of the release deployment.