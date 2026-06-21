// Fill out your copyright notice in the Description page of Project Settings.

#include "Public/PCGActor/RoomGeneratorActor.h"
#include "PCGComponent.h"
#include "PCGGraph.h"
#include "PCGPractice.h"
#include "Components/BoxComponent.h"

ARoomGeneratorActor::ARoomGeneratorActor()
{
	// Generate는 명시적 호출로만 실행 — 매 프레임 Tick 불필요
	PrimaryActorTick.bCanEverTick = false;

	// PCG GetGridBounds()는 PrimitiveComponent Bounds를 합산하므로 BoxComponent로 범위 제공
	// StaticMeshComponent는 메시 에셋 없이 Bounds가 0 — BoxComponent는 에셋 없이 크기 지정 가능
	BoundsBox = CreateDefaultSubobject<UBoxComponent>(TEXT("BoundsBox"));
	RootComponent = BoundsBox;
	BoundsBox->SetBoxExtent(FVector(500.0f, 500.0f, 100.0f)); // 에디터에서 조절 가능
	BoundsBox->SetCollisionEnabled(ECollisionEnabled::NoCollision);
	BoundsBox->SetHiddenInGame(true);

	// UPCGComponent는 UActorComponent 상속 — SetupAttachment 불필요, Actor에 등록만으로 충분
	PCGComponent = CreateDefaultSubobject<UPCGComponent>(TEXT("PCGComponent"));
	// GenerateOnDemand: Generate() 명시 호출 시에만 실행 — 스케줄러 자동 실행 없음
	PCGComponent->GenerationTrigger = EPCGComponentGenerationTrigger::GenerateOnDemand;
}

void ARoomGeneratorActor::BeginPlay()
{
	Super::BeginPlay();

	if (bGenerateOnBeginPlay)
	{
		GenerateRoom();
	}
}

void ARoomGeneratorActor::GenerateRoom()
{
	// Graph 에셋이 없으면 실행 불가
	if (!PCGGraph)
	{
		UE_LOG(LogPCGPractice, Warning,
			TEXT("ARoomGeneratorActor::GenerateRoom — PCGGraph is null. 에디터에서 PCGGraph를 할당하세요."));
		return;
	}

	// 실행할 Graph 할당 후 Generate 호출
	PCGComponent->SetGraph(PCGGraph);
	PCGComponent->Generate();
}
