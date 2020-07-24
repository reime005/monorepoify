#!/bin/bash

source ./config.cfg
workspace_path="${PWD}/workspace"

# Creating temporary local repo
rm -rf workspace
rm -rf monorepo
mkdir workspace
cd workspace

for key_value in "${repos[@]}"
do
    repo_name=${key_value%%:*} # KEY
    repo_uri=${key_value#*:} # VALUE

    echo $repo_name
    git clone $repo_uri $repo_name
    cd $repo_name

    git fetch --all

    for branch_name in "${common_branches[@]}"
    do
        git checkout $branch_name
        git pull --all
    done

    cd ..
done

for key_value in "${repos[@]}"
do
    repo_name=${key_value%%:*} # KEY

    cd $repo_name
    echo "Rewriting $repo_name"

    for branch_name in "${common_branches[@]}"
    do
        echo "Rewriting $repo_name/${branch_name}"

        git checkout $branch_name
        git filter-branch -f --index-filter "git ls-files -s | sed \"s|	\(.*\)|	${repo_name}/\1|\" | GIT_INDEX_FILE=\$GIT_INDEX_FILE.new git update-index --index-info && mv \"\$GIT_INDEX_FILE.new\" \"\$GIT_INDEX_FILE\""
    done

    cd ..
done

cd ..

# Creating new repo
mkdir monorepo
cd monorepo
git init
touch README_temp.md
git add .
git commit -m "Initial commit"

git checkout -b $common_branch

# Creating branches
for branch_name in "${common_branches[@]}"
do
    git checkout -b $branch_name
done

for key_value in "${repos[@]}"
do
    repo_name=${key_value%%:*} # KEY
    repo_uri=${key_value#*:} # VALUE

    git remote add -f $repo_name $workspace_path/$repo_name
    git checkout $common_branch

    for branch_name in "${common_branches[@]}"
    do
        git checkout $branch_name
        # Merging repo branchs
        if  git ls-remote --heads $workspace_path/$repo_name $branch_name | grep -q $branch_name; then
            git merge --allow-unrelated-histories --no-edit $repo_name/$branch_name
        # TODO add fallback branch
        #else
            #git merge --allow-unrelated-histories --no-edit $repo_name/develop
            #git add --all && git commit -m "merge ${repo_name} / ${branch_name}"
        fi
    done
done

git checkout $common_branch

mv README_temp.md README.md
git add --all && git commit -m "Rename README"
