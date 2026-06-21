// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "RoomGeneratorActor.generated.h"

class UPCGComponent;
class UPCGGraph;
class UBoxComponent;

UCLASS()
class PCGPRACTICE_API ARoomGeneratorActor : public AActor
{
	GENERATED_BODY()

public:
	ARoomGeneratorActor();

protected:
	virtual void BeginPlay() override;

public:
	// 외부에서 런타임 생성을 트리거
	UFUNCTION(BlueprintCallable, Category="RoomGenerator")
	void GenerateRoom();

	// 에디터에서 할당할 PCG Graph 에셋
	UPROPERTY(BlueprintReadWrite, EditAnywhere, Category="RoomGenerator")
	TObjectPtr<UPCGGraph> PCGGraph;
	// true면 BeginPlay 시 자동으로 Generate 실행
	UPROPERTY(BlueprintReadWrite, EditAnywhere, Category="RoomGenerator")
	bool bGenerateOnBeginPlay = true;
	// PCG GetGridBounds()가 PrimitiveComponent Bounds를 합산 — 바운드 제공용 BoxComponent 필수
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category="RoomGenerator")
	TObjectPtr<UBoxComponent> BoundsBox;
	// 생성자에서 미리 생성해두는 PCG 실행 컴포넌트
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category="RoomGenerator")
	TObjectPtr<UPCGComponent> PCGComponent;
};
